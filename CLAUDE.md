# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Muslim Library App - Persian Books Catalog. A public GitHub repository that serves as the book catalog for the Muslim Library mobile app. Contains scraped Islamic book content (JSON + covers) and a catalog manifest (`index.json`) consumed by the app for on-demand book downloads.

## Commands

```bash
ruby scraper.rb BOOK_ID              # Scrape book from API, save to books/ and covers/
```

Output files:
- `books/book_BOOK_ID.json` — book data (metadata, indexes, chapters, footnotes)
- `covers/book_BOOK_ID.jpg` — cover image

After scraping, add the book entry to `index.json` and commit.

## Repository Structure

```
├── index.json              ← catalog manifest (consumed by mobile app)
├── scraper.rb              ← scraper tool (Ruby)
├── books/
│   ├── book_280.json
│   ├── book_73.json
│   └── ...
└── covers/
    ├── book_280.jpg
    └── ...
```

## index.json — Catalog Manifest

This is the SINGLE SOURCE OF TRUTH for what books are available in the app.

Schema:
```json
{
  "version": 1,
  "books": [
    {
      "id": 280,
      "title": "کتاب التوحید",
      "author": "محمد بن عبدالوهاب",
      "cover": "covers/book_280.jpg",
      "file": "books/book_280.json",
      "size": 1024000,
      "book_version": 1
    }
  ]
}
```

**Important:**
- `id` must match the book ID from aqeedeh.com and the filename (`book_280.json`)
- `cover` and `file` paths are relative (no leading `/`)
- `size` is in bytes — use `File.size()` or `ls -l` to get accurate size
- `book_version` starts at `1`, increment when updating content
- Books array is NOT sorted — order doesn't matter for the app

## Book JSON Schema

Each `books/book_*.json` file contains:

```json
{
  "id": 280,
  "title": "کتاب التوحید",
  "author": "محمد بن عبدالوهاب",
  "description": "...",
  "cover": "covers/book_280.jpg",
  "indexes": [
    {
      "id": 1,
      "title": "باب فضل التوحید",
      "level": 1,
      "parent_index_id": null
    }
  ],
  "chapters": [
    {
      "id": 1,
      "title": "مقدمة",
      "content": "<p>بسم الله الرحمن الرحیم...</p>",
      "index_id": 1
    }
  ],
  "footnotes": [
    {
      "id": 1,
      "number": 1,
      "text": "رواه البخاری...",
      "chapter_id": 1
    }
  ]
}
```

**Field notes:**
- `indexes` — hierarchical table of contents (nested chapters/sections)
- `chapters` — actual book content (HTML with footnote markers)
- `footnotes` — footnote text extracted from content
- `content` field uses HTML: `<p>`, `<br>`, `<span>`, footnote markers like `<sup>[1]</sup>`

## Scraper (`scraper.rb`)

### What It Does

1. **Fetch book data** from `http://dl2.aqeedeh.com/text/text03/id/BOOK_ID`
2. **Download cover** from the API response (`cover_url` field)
3. **Process HTML content:**
   - Replace `<span class="symbol">X</span>` with Islamic honorifics
   - Extract footnotes using depth-counting span parser (handles nested spans correctly)
4. **Build JSON structure** with indexes, chapters, and footnotes
5. **Save files** to `books/book_BOOK_ID.json` and `covers/book_BOOK_ID.jpg`

### Symbol Replacements

The scraper replaces single-character symbols in `<span class="symbol">X</span>` tags with full Islamic honorifics:

```ruby
SYMBOL_MAP = {
  'ج' => 'صلى الله عليه وسلم',  # Prophet Muhammad (PBUH)
  'م' => 'علیه السلام',         # Other prophets (peace be upon him)
  'ض' => 'رضی الله عنه',        # Male companion (may Allah be pleased with him)
  'س' => 'رضی الله عنها',       # Female companion
  'ظ' => 'رضی الله عنهم',       # Multiple companions
  'ش' => 'رحمه الله',           # Scholar (may Allah have mercy on him)
  'ط' => 'رحمها الله',          # Female scholar
  'ف' => 'رحمهم الله',          # Multiple scholars
  'ع' => 'عز و جل',             # Allah (the Exalted)
}
```

Symbols appear in both main content and footnote text. The scraper processes both.

### Footnote Extraction

Footnotes are embedded in chapter HTML as `<span class="nt">...</span>` with nested footnote content. The scraper uses **depth-counting** to correctly extract nested spans:

```ruby
def extract_footnotes(html)
  # Counts <span> depth to handle nested footnotes
  # Returns array of {number, text} objects
end
```

After extraction, footnotes are replaced in content with `<sup>[1]</sup>` markers.

## Workflow: Adding a New Book

1. **Scrape the book:**
   ```bash
   ruby scraper.rb 280
   ```

2. **Verify output files exist:**
   ```bash
   ls books/book_280.json covers/book_280.jpg
   ```

3. **Get file size:**
   ```bash
   ls -l books/book_280.json | awk '{print $5}'
   ```

4. **Add entry to `index.json`:**
   ```json
   {
     "id": 280,
     "title": "کتاب التوحید",
     "author": "محمد بن عبدالوهاب",
     "cover": "covers/book_280.jpg",
     "file": "books/book_280.json",
     "size": 1024000,
     "book_version": 1
   }
   ```

5. **Commit and push:**
   ```bash
   git add books/book_280.json covers/book_280.jpg index.json
   git commit -m "Add book 280: کتاب التوحید"
   git push
   ```

6. **If bundling in app:** Copy `book_280.json` and `book_280.jpg` to the mobile app's `app/assets/books/` directory.

## Workflow: Updating Book Content

If you fix typos, formatting, or re-scrape:

1. **Re-scrape:**
   ```bash
   ruby scraper.rb 280
   ```

2. **Increment `book_version` in `index.json`:**
   ```json
   {
     "id": 280,
     "book_version": 2  // was 1
   }
   ```

3. **Commit:**
   ```bash
   git add books/book_280.json index.json
   git commit -m "Update book 280 content (fix formatting)"
   git push
   ```

The app will detect the version change and prompt users to update their downloaded copy.

## Mobile App Integration

The mobile app consumes this repo via GitHub raw URLs:

1. **Fetch catalog:**
   ```
   GET https://raw.githubusercontent.com/zakariaf/Muslim-Library-App-Persian-Books/main/index.json
   ```

2. **Parse `books` array** → show in "Browse Books" screen

3. **User taps download** → fetch:
   ```
   GET https://raw.githubusercontent.com/zakariaf/Muslim-Library-App-Persian-Books/main/books/book_280.json
   GET https://raw.githubusercontent.com/zakariaf/Muslim-Library-App-Persian-Books/main/covers/book_280.jpg
   ```

4. **Save to app documents directory** → import into SQLite

5. **Book available offline** in the app

## Default Bundled Books

These 8 books are bundled with the Muslim Library app (available offline from first launch):

- Book 280
- Book 73
- Book 74
- Book 1300
- Book 1318
- Book 444
- 2 additional books (already in app/muslim branch)

These MUST exist in both locations:
- This catalog repo (`books/`, `covers/`, `index.json`)
- Mobile app repo (`app/assets/books/`)

## Key Conventions

- **Language:** All book content and metadata is in Persian (Farsi). RTL text.
- **File naming:** `book_BOOK_ID.json` and `book_BOOK_ID.jpg` (lowercase, underscore separator)
- **Paths in index.json:** Always relative (`covers/book_280.jpg`, not `/covers/book_280.jpg`)
- **JSON formatting:** Use 2-space indentation
- **Commits:** Descriptive messages in English (e.g., "Add book 280: کتاب التوحید")

## Related Repositories

- **Mobile App:** [zakariaf/aqeedeh](https://github.com/zakariaf/aqeedeh) — Flutter app that consumes this catalog
- **Branch:** `app/muslim-library` — Muslim Library app variant (8 bundled books + download system)

## API Source

Books are scraped from: `http://dl2.aqeedeh.com/text/text03/id/BOOK_ID`

This API returns JSON with book metadata, indexes, chapters, and embedded footnotes. The scraper transforms this into the mobile app's expected schema.
