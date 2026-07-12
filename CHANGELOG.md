## 1.1.0 - 2026-07-12

### Added

- Version 1 of the Bible content contract, with an explicit `schemaVersion`,
  deterministic `bookOrder`, stable edition IDs, and lossless JSON-compatible
  annotations on Bible, book, chapter, verse, and metadata values
- Strict, path-aware decoded-content validation through
  `BibleDataFormatError`, plus an explicit permissive policy for intentionally
  skeletal data
- Background JSON processing where isolates are available, structured
  reading/processing/completion progress, and eager, lazy, or disabled search
  index policies
- Edition-aware `BibleVerseKey` values and JSON-restorable `BibleLocation`
  values for bookmarks, highlights, notes, and reading progress
- Result pagination metadata, snippet-relative highlight ranges, and explicit
  snippet bounds for UI search rendering
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

- Legacy data without `bookOrder` now falls back to canonical book order rather
  than JSON map insertion order; chapter and verse ordering follows declared
  numeric identifiers
- Search now applies canonical Unicode normalization by default, offers
  opt-in diacritic folding, and supports substrings in Chinese, Japanese, Thai,
  Lao, Khmer, and Myanmar text that does not delimit every word with spaces
- Search index construction is configurable for startup latency and memory,
  search/page collection stops without constructing discarded hit objects,
  and lazy indexes can be prewarmed asynchronously on isolate-capable targets
- Catalog source IDs are validated and indexed as unique edition identities;
  unknown metadata fields and nested source provenance survive round trips
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
- The minimum Dart SDK was widened from 3.10.7 to 3.4.0 after removing
  unnecessary newer-language syntax and adding minimum-SDK CI coverage
- Direct and transitive dependencies were refreshed to their latest resolvable
  versions

### Fixed

- Canonically equivalent NFC/NFD text now matches consistently, while match
  ranges continue to point into the original UTF-16 verse text
- Cropped snippets now expose their origin and snippet-relative ranges, and
  avoid splitting grapheme clusters
- All/any indexed search no longer misses query substrings in commonly
  unspaced writing systems
- Fuzzy search now applies the same unspaced-script substring behavior and
  consistently rejects negative result limits
- Malformed Bible JSON now reports stable typed errors and precise paths
  instead of leaking `TypeError`, cast, or integer parsing failures
- Translation identity, description, custom annotation fields, and explicit
  canon order are no longer lost during serialization
- Parsed cross-book ranges now honor an edition's explicit non-default book
  order, and conflicting loaded book aliases are rejected as ambiguous
- Unknown nested `BibleSource` fields stay nested instead of being flattened
  into metadata or lost on key collisions
- Public model lists and annotation trees can no longer be mutated through
  shared references
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

- Documented the version 1 content schema, migration path, edition-aware UI
  state, validation policies, search normalization, and index lifecycle
- Clarified the intentional `AGPL-3.0-or-later` code license and the independent
  copyright and licensing requirements of Bible translation content
- Added CI checks for formatting, analysis, tests, coverage, web compilation,
  and the pub.dev archive
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

### Bug-fix note

- Public model collections were always intended to be immutable. The exposed
  mutation paths were fixed; derive changed values with constructors or
  `copyWith()` rather than mutating `Bible.books`, `Book.chapters`, or
  `Chapter.verses`.

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
