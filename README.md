# Bible IO 📖

A modern Dart package for loading and working with structured Bible text data, featuring Dart's latest language features for an idiomatic, functional API.

## ✨ Modern Dart Features

- **Async/Await**: Load Bibles asynchronously with `Bible.load()`
- **Operator Overloading**: Access content with `bible[book]`, `bible[(book, chapter)]`, `bible[(book, chapter, verse)]`
- **Result Types**: Functional error handling with `Result<T>` instead of exceptions
- **Extension Methods**: Fluent, chainable API with extension methods
- **Records & Typedefs**: Modern type system with `BibleReference` records
- **Pattern Matching**: Use switch expressions and pattern matching
- **Null Safety**: Comprehensive null-safe APIs with `verseOrNull()`, `versesOrNull()`
- **Functional Programming**: Iterables, folds, maps, and lazy evaluation
- **Statistics & Analytics**: Built-in stats for Bible, Book, Chapter, and Verse analysis

## 🚀 Installation

```yaml
dependencies:
  bible_io: ^1.0.0
  bible_io_references: ^1.0.0
```

## 📚 Quick Start

### Async Loading
```dart
import 'package:bible_io/bible_io.dart';

// Load asynchronously (modern Dart!)
final bible = await Bible.load('path/to/en_kjv.json');
```

### Operator Overloading
```dart
// Convenient access with index operators
final genesis = bible[BibleBookEnum.genesis];
final chapter1 = bible[(BibleBookEnum.genesis, 1)];
final verse = bible[(BibleBookEnum.genesis, 1, 1)];
```

### Result-Based Error Handling
```dart
// Functional error handling (no exceptions!)
final result = bible.getVerseResult(BibleBookEnum.genesis, 1, 1);
switch (result) {
  case Success(value: final verse):
    print('Found: ${verse.text}');
  case Failure(error: final error):
    print('Error: $error');
}
```

### Fluent Extension Methods
```dart
// Chain operations fluently
final loveVerses = bible
    .searchAdvanced(text: 'love', maxResults: 10, wholeWords: true)
    .verses
    .where((v) => v.book == BibleBookEnum.john)
    .toList();
```

### Null-Safe Operations
```dart
// Safe access with null safety
final verse = bible.verseOrNull('Genesis 1:1');
final verses = bible.versesOrNull('Genesis 1:1-3');
```

### Statistics & Analytics
```dart
// Built-in statistics
print('Bible stats: ${bible.stats}');
// BibleStats(books: 66, chapters: 1189, verses: 31102, words: 835473)

print('Genesis stats: ${genesis.stats}');
// BookStats(chapters: 50, verses: 1533, words: 38302)
```

## 🔍 Advanced Search

```dart
// Advanced search with filtering
final results = bible.searchAdvanced(
  text: 'God',
  mode: SearchMode.exact,       // exact phrase; use all/any for term search
  book: BibleBookEnum.genesis,  // Filter by book
  caseSensitive: false,
  wholeWords: true,
  maxResults: 20,
);

// Group results by book
final byBook = results.byBook;
for (final entry in byBook.entries) {
  print('${entry.key.fullName}: ${entry.value.length} verses');
}
```

## 🎯 Functional Programming

```dart
// Use iterables and functional patterns
final allVerses = bible.allVerses;
final longVerses = allVerses.where((v) => v.length > 200);
final totalWords = allVerses.fold<int>(0, (sum, verse) => sum + verse.words.length);

// Lazy evaluation with generators
final genesisVerses = genesis.allVerses;
final versesWithGod = genesisVerses.where((v) => v.containsWord('God'));
```

## 📊 Reference Parsing

```dart
// Parse references from strings
final verse = bible.getVerseByRef('John 3:16');
final verses = bible.getVerseRangeByRef('Genesis 1:1-3');

// Safe parsing with Results
final result = bible.getVerseByRefResult('Invalid Reference 1:1');
result.fold(
  (error) => print('Parse error: $error'),
  (verse) => print('Found: ${verse.reference}'),
);
```

## 🏗️ API Overview

### Core Classes
- **`Bible`**: Main container with async loading, operator overloading, and search
- **`Book`**: Book-level operations with statistics and verse counting
- **`Chapter`**: Chapter operations with verse filtering
- **`Verse`**: Individual verses with text analysis and reference formatting

### Result Types
- **`Result<T>`**: Functional error handling (Success/Failure)
- **`SearchResults`**: Search results with grouping and metadata
- **`*Stats`**: Statistics classes for Bible, Book, Chapter, and Verse

### Extension Methods
- **`BibleExtensions`**: Fluent Bible operations
- **`BookExtensions`**: Book analysis and filtering
- **`ChapterExtensions`**: Chapter operations
- **`VerseExtensions`**: Verse utilities and formatting

## 📋 JSON Format

The package expects Bible data in this JSON structure:

```json
{
  "language": "English",
  "books": {
    "gn": {
      "name": "Genesis",
      "chapters": {
        "1": {
          "1": "In the beginning God created the heaven and the earth.",
          "2": "And the earth was without form, and void..."
        }
      }
    }
  }
}
```

## 🔧 Migration from Legacy API

### Old Way
```dart
// Synchronous loading with exceptions
final bible = Bible('path/to/bible.json');
final verse = bible.getVerse(BibleBookEnum.genesis, 1, 1); // Throws!
```

### New Way
```dart
// Async loading with Result types
final bible = await Bible.load('path/to/bible.json');
final result = bible.getVerseResult(BibleBookEnum.genesis, 1, 1);
final verse = result.value; // Safe!
```

## 📈 Performance Features

- **Lazy Search Index**: Built on-demand, invalidated when needed
- **Iterable Generators**: Memory-efficient verse iteration
- **Functional Operations**: Chainable without intermediate collections
- **Async Loading**: Non-blocking file I/O

## 🧪 Testing

```bash
dart test
```

All tests pass with comprehensive coverage of modern Dart features.

## 📖 Examples

See `lib/bible_example.dart` for a complete showcase of all modern Dart features in action.

---

**Made with ❤️ and modern Dart**

```bash
dart run bin/package.dart <path_to_bible_json>
```

## Running Tests

```bash
dart test
```

## Dependencies

This example depends on the `bible_io_references` package from pub.dev:

```yaml
dependencies:
  bible_io_references: ^1.0.0
```
