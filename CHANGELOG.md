## 1.1.0 - 2026-07-12

### Added

- Platform-neutral loading from Flutter-style asset bundles, UTF-8 bytes,
  decoded JSON maps, and JSON strings, while retaining asynchronous file
  loading on `dart:io` platforms
- Translation metadata, `BibleSource` and `BibleCatalog` helpers, stable
  `BibleLocation` values, and display-ready search hits with snippets and
  match ranges
- Full `bible_io_references` 1.1 integration, including typed non-throwing
  parsing, edition-aware book aliases, multilingual language preferences,
  rich passage expressions, cross-book ranges, localized formatting, and
  OSIS/USFM interoperability
- Support for short, full-name, OSIS, and USFM book identifiers in Bible JSON
- A conventional `example/bible_io_example.dart` package example

### Changed

- Book, chapter, verse, search-result, catalog-result, and passage-result
  collections are defensively copied and exposed as immutable values
- Chapter and verse access now uses declared numbers instead of list offsets,
  safely supporting sparse and out-of-order source JSON
- Chapter navigation follows the edition's actual declared chapter numbers
  and book order
- Search value types now live in a dedicated module, removing the previous
  `Bible`/extensions import cycle
- Fuzzy search and word statistics now use consistent Unicode tokenization and
  Unicode scalar-aware edit distances
- Internal imports and the public re-export now use the conventional
  `bible_io_references.dart` entry point
- Direct and transitive dependencies were refreshed to their latest resolvable
  versions

### Fixed

- Bible metadata now preserves nested source information across JSON
  round-trips
- Nested language catalog maps no longer create bogus source entries
- Fuzzy search now handles blank queries, non-positive result limits, invalid
  distance limits, and non-ASCII text correctly
- Search match ranges remain accurate for case-insensitive Unicode matching
- Duplicate books, chapters, and verses, invalid parent relationships, and
  non-positive declared numbers are rejected instead of corrupting indexes
- Result helpers no longer include captured stack traces in user-facing error
  strings

### Documentation and tests

- Expanded the README with platform-neutral loading, catalogs, metadata,
  multilingual parsing, rich passages, OSIS/USFM, locations, and search-hit
  examples
- Added regression coverage for model invariants, metadata/catalog
  round-tripping, Unicode fuzzy search, cross-book and rich-passage resolution,
  language detection, and machine identifiers
- Replaced the placeholder package test and reduced repeated loading of the
  large KJV fixture across test groups
- Deprecated the legacy `lib/bible_example.dart` entry point; it remains
  available for compatibility and will be removed in a future major release

### Compatibility note

- Public model collections are now unmodifiable. Code that previously mutated
  `Bible.books`, `Book.chapters`, or `Chapter.verses` should construct a new
  model graph instead.

## 1.0.1 - 2026-04-25

### Added

- `SearchMode` support for exact phrases, all terms, or any term
- Reusable `SearchOptions` with book, chapter, verse, case-sensitivity,
  whole-word, and result-limit filters
- Unicode-aware tokenization for Arabic, Chinese, Greek, Hebrew, Korean,
  Russian, and other scripts
- A dedicated multilingual search and UTF-8 regression suite

### Changed

- `search()` now has explicit all-term semantics, distinct from exact phrase
  search
- Advanced search moved to a single canonical implementation on `Bible`
- Indexed candidate selection preserves Bible order while using the rarest
  matching term to reduce unnecessary work
- The README was reorganized around installation, navigation, search modes,
  result helpers, statistics, testing, and publishing

### Fixed

- File loading now uses a chunked UTF-8 decoder, preventing multibyte
  characters from being corrupted when they span stream chunks
- Whole-word matching no longer relies on ASCII-oriented `\b` boundaries
- Exact, all-term, and any-term searches now behave consistently across
  punctuation and non-Latin text
- Empty files report completed progress without dividing by zero
- Result limits are applied while collecting matches in stable source order

## 1.0.0 - 2026-04-01

### Added

- Asynchronous Bible loading with progress callbacks
- Operator access through `bible[book]`, `bible[(book, chapter)]`, and
  `bible[(book, chapter, verse)]`
- Sealed `Result<T>` values and result-based lookup helpers
- Extension methods and statistics for Bible, book, chapter, and verse values
- Advanced and fuzzy search, JSON export, and performance metrics
- Detailed Bible-specific errors with context

### Changed

- Adopted modern Dart records, sealed classes, pattern matching, and null
  safety throughout the public API
- Replaced the legacy synchronous path constructor with `Bible.load(path)`
- Updated the minimum Dart SDK to 3.10.7

### Development

- Added benchmark and coverage tooling
- Expanded package documentation, examples, and automated tests

## 0.1.0

- Initial package release
- Loaded Bible translations from JSON files
- Added book, chapter, and verse navigation
- Added cached text search and reference-based lookup
- Added errors for invalid books, chapters, verses, and references
