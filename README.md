# Bible IO

A Dart package for loading and working with structured Bible text data. It supports async JSON loading, reference parsing, operator-based navigation, result-style error handling, statistics helpers, and Unicode-aware search.

## Features

- Async file loading with `Bible.load()` plus asset, UTF-8 byte, decoded-map,
  and JSON-string constructors
- UTF-8 safe loading for non-Latin Bible text
- Immutable, number-aware book/chapter/verse models (including sparse numbering)
- Indexed search with stable canonical Bible order
- Unicode-aware tokenization for Arabic, Chinese, Greek, Russian, Korean, Hebrew, and other scripts
- Exact phrase, all-terms, and any-term advanced search modes
- Whole-word matching without relying on ASCII-oriented `\b`
- Operator access with `bible[book]`, `bible[(book, chapter)]`, and `bible[(book, chapter, verse)]`
- Multilingual reference parsing through `bible_io_references`
- Cross-book ranges and rich passages (books, chapter ranges, verse lists, and
  semicolon-separated sequences)
- Typed parse results, localized formatting, and OSIS/USFM interoperability
- Translation metadata and catalog helpers for multi-Bible applications
- Result-based helpers such as `getVerseResult()`
- Statistics helpers for Bible, book, chapter, and verse data

## Installation

```yaml
dependencies:
  bible_io: ^1.1.0
```

`bible_io_references` is exported by this package, so consumers can import `package:bible_io/bible_io.dart` for both Bible IO and reference types.

## Quick Start

```dart
import 'package:bible_io/bible_io.dart';

Future<void> main() async {
  final bible = await Bible.load('path/to/en_kjv.json');

  final verse = bible.getVerse(BibleBookEnum.genesis, 1, 1);
  print(verse.text);

final john316 = bible.getVerseByRef('John 3:16');
print(john316.text);
}
```

## Loading and Metadata

File loading uses `dart:io`. Platform-neutral applications can load from an
asset bundle, UTF-8 bytes, a decoded map, or a JSON string:

```dart
final fromAsset = await Bible.loadAsset(rootBundle, 'assets/kjv.json');
final fromBytes = Bible.fromUtf8Bytes(bytes);
final fromMap = Bible.fromDecodedJson(decodedJson);

print(fromAsset.translationName);
print(fromAsset.languageCode);
print(fromAsset.textDirection);
```

`BibleCatalog` reads list- or map-shaped translation catalogs and groups
`BibleSource` values by language:

```dart
final catalog = BibleCatalog.fromJson(catalogJson);
final englishSources = catalog.forLanguage('en');
```

## Navigation

```dart
final genesis = bible[BibleBookEnum.genesis];
final genesis1 = bible[(BibleBookEnum.genesis, 1)];
final genesis1v1 = bible[(BibleBookEnum.genesis, 1, 1)];

final verses = bible.getVerses(BibleBookEnum.genesis, 1);
final range = bible.getVerseRangeByRef('Genesis 1:1-3');
```

Chapter navigation uses stable `BibleLocation` values:

```dart
const current = BibleLocation(book: BibleBookEnum.genesis, chapter: 50);
final next = bible.nextChapter(current); // Exodus 1
```

## References and Rich Passages

Reference parsing is multilingual by default, while the loaded Bible's
language and custom book names are used as tie-break preferences. A concrete
`inputLanguage` makes parsing strict:

```dart
final parsed = bible.parseReference('Juan 3:16');
if (parsed case ParseSuccess(value: final reference)) {
  final verses = bible.resolveReference(reference);
  print(verses.single.text);
}

final spanish = bible.getVerseByRef(
  'Juan 3:16',
  inputLanguage: BibleLanguageEnum.spanish,
);
```

Use `getPassage()` for the richer 1.1 grammar. Results are immutable and keep
the expression's order and intentional overlaps:

```dart
final selection = bible.getPassage(
  'John 3:16,18-20; Acts 2:1-4; Romans 8',
);

final crossBook = bible.getVerseRangeByRef(
  'John 21:25-Acts 1:2',
);
```

OSIS and USFM values from `bible_io_references` resolve directly:

```dart
final osis = referenceFromOsisIdentifier('John.3.16');
final verse = bible.resolveReference(osis).single;
```

## Search

`search()` is a fast all-terms search. It tokenizes the query and returns verses containing every token. It is not an exact phrase search.

```dart
final results = bible.search('in the beginning');
```

Use `searchAdvanced()` when you need explicit search behavior:

```dart
final exactPhrase = bible.searchAdvanced(
  text: 'in the beginning',
  mode: SearchMode.exact,
);

final allTerms = bible.searchAdvanced(
  text: 'faith hope',
  mode: SearchMode.all,
);

final anyTerm = bible.searchAdvanced(
  text: 'faith hope',
  mode: SearchMode.any,
  maxResults: 20,
);
```

Advanced search also supports scope filters and whole-word matching:

```dart
final results = bible.searchAdvanced(
  text: 'God',
  mode: SearchMode.exact,
  book: BibleBookEnum.genesis,
  chapter: 1,
  caseSensitive: false,
  wholeWords: true,
  maxResults: 10,
);

for (final verse in results.verses) {
  print('${verse.book.fullName} ${verse.chapterNumber}:${verse.verseNumber} ${verse.text}');
}
```

For UI rendering, `SearchResults.hits` includes the resolved `Book`, display
reference, snippet, and UTF-16 match ranges:

```dart
for (final hit in results.hits) {
  print('${hit.reference}: ${hit.snippet}');
}
```

For reusable search configuration, use `SearchOptions`:

```dart
final results = bible.searchWithOptions(
  'love mercy',
  const SearchOptions(
    mode: SearchMode.all,
    wholeWords: true,
    maxResults: 25,
  ),
);
```

## Result-Based Helpers

```dart
final result = bible.getVerseResult(BibleBookEnum.genesis, 1, 1);

switch (result) {
  case Success(value: final verse):
    print(verse.text);
  case Failure(error: final error):
    print(error);
}
```

## Statistics

```dart
print(bible.stats);
print(bible.getBook(BibleBookEnum.genesis).stats);
print(bible.getChapter(BibleBookEnum.genesis, 1).stats);
```

## JSON Format

The package expects Bible data in this structure:

```json
{
  "language": "English",
  "metadata": {
    "translationName": "King James Version",
    "abbreviation": "KJV",
    "languageCode": "en"
  },
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

## Testing

```bash
dart analyze
dart test
```

If you are using the Flutter SDK's bundled Dart executable:

```bash
flutter test
```

## Publishing

Before publishing, verify the package:

```bash
dart pub publish --dry-run
```

Publish to pub.dev:

```bash
dart pub publish
```

If you are using Flutter's bundled Dart toolchain, these equivalents also work:

```bash
flutter pub publish --dry-run
flutter pub publish
```

## Example

```bash
dart run bin/package.dart path/to/bible.json
```
