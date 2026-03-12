# Muslim Library App - Persian Books Catalog

Public book catalog for the [Muslim Library mobile app](https://github.com/zakariaf/aqeedeh). Contains scraped Islamic book content, covers, and metadata served to the app for on-demand downloads.

## Repository Structure

```
Muslim-Library-App-Persian-Books/
├── README.md                    ← this file
├── CLAUDE.md                    ← AI assistant guidance
├── scraper.rb                   ← book scraper tool
├── index.json                   ← catalog manifest (consumed by the app)
├── books/
│   ├── book_280.json
│   ├── book_73.json
│   └── ...
└── covers/
    ├── book_280.jpg
    └── ...
```

## Quick Start

### 1. Scrape a Book

```bash
ruby scraper.rb BOOK_ID
```

This fetches book content from the aqeedeh.com API, processes it, and saves:
- `books/book_BOOK_ID.json` — book data (title, author, chapters, content, footnotes)
- `covers/book_BOOK_ID.jpg` — cover image

### 2. Add to Catalog

Edit `index.json` and add an entry:

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

### 3. Push to GitHub

```bash
git add books/ covers/ index.json
git commit -m "Add book 280: کتاب التوحید"
git push
```

The app will now show this book in its download catalog.

## index.json Schema

The catalog manifest consumed by the mobile app.

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

**Fields:**
- `version` — catalog schema version (currently `1`)
- `books` — array of book metadata objects
  - `id` — unique book ID (from aqeedeh.com)
  - `title` — book title (Persian)
  - `author` — author name (Persian)
  - `cover` — relative path to cover image
  - `file` — relative path to book JSON
  - `size` — file size in bytes (for download progress UI)
  - `book_version` — content version (increment when updating scraped content)

## Book JSON Schema

Each book JSON contains:

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
      "content": "<p>بسم الله...</p>",
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

## Scraper Details

**What it does:**
1. Fetches book metadata and content from `http://dl2.aqeedeh.com/text/text03/id/BOOK_ID`
2. Downloads cover image from the API response
3. Processes HTML content:
   - Replaces `<span class="symbol">X</span>` with Islamic honorifics (ﷺ, ؑ, etc.)
   - Extracts footnotes with proper depth counting for nested spans
4. Builds the book JSON with indexes (table of contents), chapters, and footnotes
5. Saves everything to `books/` and `covers/`

**Requirements:**
- Ruby 2.7+
- `net/http`, `json`, `fileutils` (stdlib)

**Symbol replacements:**
- `ج` → `صلى الله عليه وسلم` (peace be upon him)
- `م` → `علیه السلام` (peace be upon him)
- `ض` → `رضی الله عنه` (may Allah be pleased with him)
- See `SYMBOL_MAP` in `scraper.rb` for the full list

## How the App Uses This

1. App fetches `https://raw.githubusercontent.com/zakariaf/Muslim-Library-App-Persian-Books/main/index.json`
2. Shows a "Browse Books" screen with all available books
3. User taps download → app fetches the book JSON and cover
4. Saves files to app documents directory
5. Imports book into local SQLite database (same path as bundled books)
6. Book is now available offline in the app

## Updating Book Content

If you fix scraped content (typos, formatting, etc.):

1. Re-scrape: `ruby scraper.rb BOOK_ID`
2. Increment `book_version` in `index.json` for that book
3. Commit and push

The app will detect the version mismatch and offer users an update.

## Default Bundled Books

These books are bundled with the app (available offline from first launch):

- Book 280
- Book 73
- Book 74
- Book 1300
- Book 1318
- Book 444
- 2 additional books (already in app)

These books MUST be in this catalog repo AND copied to the mobile app's `app/assets/books/` directory.

## Contributing

This is a public catalog. Contributions welcome:
- Fix typos or formatting in scraped content
- Improve the scraper's HTML processing
- Add new books (if you have permission to distribute them)

## License

Book content is sourced from aqeedeh.com. Check their terms before redistributing.
