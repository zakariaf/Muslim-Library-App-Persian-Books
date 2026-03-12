#!/usr/bin/env ruby
# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

class BookScraper
  BASE_URI = 'https://aqeedeh.com/api'

  SYMBOL_MAP = {
    'ج' => ' (صلى الله عليه وسلم)',
    'ج ' => ' (صلى الله عليه وسلم)',
    'س' => ' (رضي الله عنه)',
    'س ' => ' (رضي الله عنه)',
    'ب' => ' (رضي الله عنهما)',
    'ب ' => ' (رضي الله عنهما)',
    'ش' => ' (رضي الله عنهم)',
    'ش ' => ' (رضي الله عنهم)',
    'ل' => ' (رضي الله عنها)',
    'ل ' => ' (رضي الله عنها)',
    "\u00F7" => ' (عليه السلام)',       # ÷
    "\u2020" => ' (عليهم السلام)',      # †
    "\u2020 " => ' (عليهم السلام)', # † with trailing space
    "\u2018" => ' (رضي الله عنها)', # '
    "\u2018 " => ' (رضي الله عنها)', # ' with trailing space
    '/' => ' (رحمه الله)'
  }.freeze

  KEEP_SYMBOLS = Set.new([
                           "\uFD3E", "\uFD3F", # ﴾ ﴿
                           "\u00BB", # »
                           "\u00AC" # ¬
                         ]).freeze

  attr_reader :book_id, :output_path

  def initialize(book_id, output_path = nil)
    @book_id = book_id
    @output_path = output_path || "book_#{book_id}.json"
  end

  def run
    puts "Scraping book #{book_id}..."

    book = fetch_book_details
    indexes_data = fetch_indexes
    indexes = process_indexes(indexes_data)

    result = { book: book, indexes: indexes }

    File.write(output_path, JSON.pretty_generate(result))
    download_cover(book[:image])
    puts "\nDone! Written to #{output_path}"
    print_summary(result)
  end

  private

  def fetch_book_details
    puts 'Fetching book details...'
    data = fetch_json("#{BASE_URI}/book_details/#{book_id}/fa")
    {
      id: book_id.to_i,
      title: data['name'],
      description: data['minbody'],
      writer: data['writer_name'],
      translator: data['translator_name'],
      lang: data['lang'],
      image: data['image_path'],
      category: data['cat_name']
    }
  end

  def fetch_indexes
    puts 'Fetching indexes...'
    fetch_json("#{BASE_URI}/book/get_indexes/#{book_id}/fa")
  end

  def process_indexes(indexes_data)
    # Count total items for progress (chapters + indexes without chapters)
    total = indexes_data.sum { |idx| (idx['chapters']&.length || 0).zero? ? 1 : idx['chapters'].length }
    fetched = 0

    indexes_data.map do |index_data|
      chapters_data = index_data['chapters'] || []

      index = { iid: index_data['iid'], title: clean_title(index_data['title']) }

      if chapters_data.empty?
        # Index with no chapters — fetch content directly (paper icon)
        fetched += 1
        print "\r[#{fetched}/#{total}] Fetching index #{index_data['iid']}..."
        $stdout.flush

        content_data = fetch_index_content(index_data['iid'])
        html = content_data['content'] || ''
        processed = process_html(html)
        sleep 0.1

        index[:content] = processed[:content]
        index[:footnotes] = processed[:footnotes]
      else
        # Index with chapters (folder icon)
        index[:chapters] = chapters_data.map do |ch|
          fetched += 1
          print "\r[#{fetched}/#{total}] Fetching chapter #{ch['cid']}..."
          $stdout.flush

          content_data = fetch_chapter_content(index_data['iid'], ch['cid'])
          html = content_data['content'] || ''
          processed = process_html(html)
          sleep 0.1

          {
            cid: ch['cid'],
            title: clean_title(ch['title']),
            content: processed[:content],
            footnotes: processed[:footnotes]
          }
        end
      end

      index
    end
  end

  def process_html(html)
    footnotes = extract_footnotes!(html)
    content = replace_symbols(html)
    content = clean_footnote_refs(content)
    content = clean_whitespace(content)
    footnotes.each do |f|
      f[:text] = replace_symbols(f[:text])
      f[:text] = f[:text].gsub("\t", '').gsub("\r\n", '<br>')
    end
    { content: content, footnotes: footnotes }
  end

  def fetch_index_content(iid)
    fetch_json("#{BASE_URI}/book/get_index_content/#{book_id}/#{iid}")
  end

  def fetch_chapter_content(iid, cid)
    fetch_json("#{BASE_URI}/book/get_chapter_content/#{book_id}/#{iid}/#{cid}")
  end

  def extract_footnotes!(html)
    footnotes = []
    # Match noteBody spans handling nested <span>...</span> inside
    # Match both id="noteBody..." and id="noteBod..." (API typo in some books)
    pattern = %r{<span\s+(?:id="noteBod(?:y)?(\d+)"\s+class="noteBody"|class="noteBody"\s+id="noteBod(?:y)?(\d+)")>}
    while (m = html.match(pattern))
      fn_id = (m[1] || m[2]).to_i
      start_pos = m.begin(0)
      # Find matching </span> by counting nesting depth
      inner_start = m.end(0)
      depth = 1
      pos = inner_start
      while depth > 0 && pos < html.length
        if html[pos..].start_with?('<span')
          depth += 1
          pos += 5
        elsif html[pos..].start_with?('</span>')
          depth -= 1
          break if depth == 0
          pos += 7
        else
          pos += 1
        end
      end
      inner_text = html[inner_start...pos]
      end_pos = pos + 7 # skip past </span>
      footnotes << { id: fn_id, text: inner_text.strip }
      html[start_pos...end_pos] = ''
    end
    footnotes.sort_by { |f| f[:id] }
  end

  def replace_symbols(html)
    # Use multiline flag so .*? matches across \r\n inside symbol spans
    html.gsub(%r{<span class="symbol">(.*?)</span>}m) do
      inner = ::Regexp.last_match(1)
      # Strip <br> tags and whitespace that the API sometimes embeds in symbol spans
      cleaned = inner.gsub(%r{<br\s*/?>}, '').strip
      if (replacement = SYMBOL_MAP[cleaned])
        replacement
      elsif cleaned.empty? || KEEP_SYMBOLS.include?(cleaned)
        cleaned
      else
        cleaned # Unknown symbol, keep as-is
      end
    end
  end

  def clean_footnote_refs(html)
    # Convert <span class="footnote">[n]</span> and variants with name="noteBodyN" to plain [n]
    html.gsub(%r{<span\s+[^>]*class="footnote"[^>]*>\[([\d۰-۹٠-٩]+)\]</span>}, '[\1]')
  end

  def clean_whitespace(html)
    html.gsub("\t", '').gsub("\r\n", "\n").gsub(%r{<br\s*/?>\s*\n}, '<br>').gsub("\n", '')
  end

  def clean_title(title)
    return title unless title

    # Truncate at content leaking into title (</p>, <h tags, <div)
    title = title.sub(%r{</p>.*}m, '')
    title = title.sub(/<h[1-6][\s>].*\z/m, '')
    title = title.sub(%r{<div[\s>].*\z}m, '')
    title = replace_symbols(title)
    title = clean_footnote_refs(title)
    # Strip all HTML tags except <br> (needed for two-line display)
    title = title.gsub(%r{<(?!br\s*/?>)[^>]*>}i, '')
    # Strip malformed/incomplete tags
    title = title.gsub(/<[^>]*\z/, '')
    clean_whitespace(title)
  end

  def download_cover(image_url)
    return unless image_url && !image_url.empty?

    cover_path = File.join('app', 'assets', 'books', "book_#{book_id}.jpg")
    puts "\nDownloading cover image..."
    uri = URI(image_url)
    attempts = 0
    begin
      attempts += 1
      response = Net::HTTP.get_response(uri)
      if response.is_a?(Net::HTTPRedirection)
        uri = URI(response['location'])
        raise 'redirect'
      end
      raise "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      File.binwrite(cover_path, response.body)
      puts "  Saved to #{cover_path} (#{response.body.bytesize} bytes)"
    rescue StandardError => e
      if attempts < 3
        sleep 1
        retry
      end
      warn "  WARNING: Failed to download cover: #{e.message}"
    end
  end

  def fetch_json(url)
    uri = URI(url)
    attempts = 0
    begin
      attempts += 1
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.open_timeout = 120
      http.read_timeout = 300
      response = http.get(uri.request_uri)
      raise "HTTP #{response.code} for #{url}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue StandardError => e
      if attempts < 3
        sleep 1
        retry
      end
      warn "\nERROR: #{e.message} (#{url})"
      raise
    end
  end

  def print_summary(result)
    indexes = result[:indexes]
    chapter_count = indexes.sum { |idx| idx[:chapters]&.length || 0 }
    footnote_count = indexes.sum do |idx|
      if idx[:chapters]
        idx[:chapters].sum { |ch| ch[:footnotes].length }
      else
        idx[:footnotes]&.length || 0
      end
    end
    puts "  Indexes:   #{indexes.length}"
    puts "  Chapters:  #{chapter_count}"
    puts "  Footnotes: #{footnote_count}"
  end
end

if __FILE__ == $0
  if ARGV.empty?
    puts 'Usage: ruby scraper.rb BOOK_ID [OUTPUT_PATH]'
    exit 1
  end

  book_id = ARGV[0]
  output_path = ARGV[1]
  BookScraper.new(book_id, output_path).run
end
