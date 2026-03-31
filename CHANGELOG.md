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
