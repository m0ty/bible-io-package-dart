## 1.1.0 - 2026-07-12

### Added

- Platform-neutral asset, UTF-8 byte, decoded-map, and JSON-string loading
- A conventional `example/bible_io_example.dart` package example; the legacy
  `lib/bible_example.dart` entry point is deprecated
- Bible source metadata, translation catalogs, stable locations, and
  display-ready search hits
- `bible_io_references` 1.1 integration with typed parsing, loaded-book
  aliases, rich passage resolution, cross-book ranges, and OSIS/USFM interop

### Changed

- Book, chapter, verse, search-result, and passage-result collections are
  defensively copied and exposed as immutable values
- Chapter and verse access now uses declared numbers, supporting sparse and
  out-of-order source JSON safely
- Search types live in a dedicated module, removing the Bible/extensions
  import cycle
- Fuzzy search and word statistics now tokenize Unicode text consistently

### Fixed

- Bible metadata now preserves nested source information across JSON
  round-trips
- Nested language catalog maps no longer produce bogus sources
- Fuzzy search handles blank queries, non-positive result limits, Unicode
  scalar edits, and invalid distance limits correctly
- Chapter navigation now follows actual declared chapter numbers

## 1.0.0

### ✨ Major Features
- **Async Loading**: Non-blocking Bible loading with progress callbacks
- **Operator Overloading**: Convenient access with `bible[book]`, `bible[(book, chapter)]`, `bible[(book, chapter, verse)]`
- **Result Types**: Functional error handling with sealed `Result<T>` classes
- **Extension Methods**: Fluent, chainable API for Bible, Book, Chapter, and Verse operations
- **Advanced Search**: Fuzzy search, whole word matching, case sensitivity, and filtering
- **Statistics & Analytics**: Built-in stats for Bible, Book, Chapter, and Verse analysis
- **JSON Export**: Save Bible data back to JSON format
- **Performance Monitoring**: Track load times, memory usage, and search index metrics
- **Enhanced Error Handling**: Detailed error messages with stack traces and context

### 🔧 Improvements
- Modern Dart patterns: records, sealed classes, pattern matching
- Comprehensive null safety throughout
- Lazy evaluation and memory-efficient operations
- Better IDE support with improved type annotations
- Enhanced documentation and examples

### 🐛 Bug Fixes
- Fixed async initialization in tests
- Improved error handling for malformed data
- Better resource cleanup in async operations

### 📚 Documentation
- Comprehensive README with modern Dart examples
- Updated API documentation
- Performance and usage guidelines

### 🔄 Breaking Changes
- Bible constructor changed from synchronous `Bible(path)` to async `Bible.load(path)`
- All tests updated to use async initialization

### 📦 Dependencies
- Added benchmark_harness for performance testing
- Added coverage for test coverage analysis
- Updated to Dart SDK ^3.10.7

---

## 0.1.0

- Initial release of bible_io package.
- Load Bible translations from JSON files.
- Navigate books, chapters, and verses.
- Fast word search with cached index.
- Error handling for invalid references.
