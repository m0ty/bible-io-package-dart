# Bible IO

Bible IO is a Dart content and state-of-truth layer for Bible applications. It
loads validated translation data into immutable, edition-aware models and
provides stable navigation, multilingual references, UI-ready search results,
and lossless JSON round-tripping.

## Features

- Immutable, number-aware `Bible`, `Book`, `Chapter`, and `Verse` models
- Versioned content schema with explicit canon order and extensible annotations
- Strict validation with path-aware `BibleDataFormatError` failures
- Background JSON processing and structured progress for responsive UIs
- Eager, lazy, or disabled search indexes to fit different memory budgets
- Canonically normalized multilingual search, including unspaced scripts
- Paginated, UI-ready hits with grapheme-safe snippets and accurate ranges
- Multilingual reference and passage parsing through `bible_io_references` 1.1
- Edition-aware keys for bookmarks, highlights, notes, and reading progress
- Translation metadata and catalog helpers for multi-edition applications
- Result-based lookup helpers for application boundaries

## Installation

Bible IO supports Dart 3.4 and later.

```yaml
dependencies:
  bible_io: ^1.1.0
```

`bible_io_references` is exported by this package. Importing
`package:bible_io/bible_io.dart` provides both Bible IO and reference types.

## Quick start

```dart
import 'package:bible_io/bible_io.dart';

Future<void> main() async {
  final bible = await Bible.load('path/to/en_kjv.json');

  final genesis11 = bible.getVerse(BibleBookEnum.genesis, 1, 1);
  final john316 = bible.getVerseByRef('John 3:16');

  print(genesis11.text);
  print(john316.text);
}
```

## Loading without blocking the UI

`Bible.load()` reads files on platforms with `dart:io`. JSON decoding, model
validation, and eager index construction run in a background isolate by
default where isolates are available:

```dart
final bible = await Bible.load(
  'assets/en_kjv.json',
  onLoadProgress: (progress) {
    print('${progress.phase}: ${(progress.fraction * 100).round()}%');
  },
);
```

Flutter and other platform-neutral applications can load through an asset
bundle, UTF-8 bytes, a decoded map, or a JSON string:

```dart
final fromAsset = await Bible.loadAsset(rootBundle, 'assets/kjv.json');
final fromBytes = Bible.fromUtf8Bytes(bytes);
final fromMap = Bible.fromDecodedJson(decodedJson);
final fromString = await Bible.fromJsonAsync(jsonString);
```

On platforms without isolate support, async construction falls back to the
current isolate. Use `parseInBackground: false` only when synchronous
processing is intentional.

Search indexes can be built eagerly, on first indexed search, or not retained:

```dart
final options = const BibleLoadOptions(
  searchIndexMode: SearchIndexMode.disabled,
);
final bible = Bible.fromDecodedJson(data, options: options);

print(bible.hasSearchIndex);
bible.prewarmSearchIndex();
bible.clearSearchIndex();
```

With `SearchIndexMode.disabled`, searches scan the content and
`prewarmSearchIndex()` does not retain an index.

With `SearchIndexMode.lazy`, the first indexed search builds synchronously.
Call `await bible.prewarmSearchIndexAsync()` ahead of that search when native
UI responsiveness matters.

## Edition identity and persisted UI state

Give every translation or revision a stable metadata `id`. A verse location is
only unique inside one edition, so persist `BibleVerseKey` values for bookmarks,
highlights, notes, and reading progress:

```dart
final verse = bible.getVerseByRef('John 3:16');
final editionId = bible.metadata.id;

if (editionId != null) {
  final key = BibleVerseKey.fromVerse(editionId, verse);
  final stored = key.toJson();
  final restored = BibleVerseKey.fromJson(stored);
  print(restored);
}
```

`BibleLocation` also supports `copyWith()`, `toJson()`, `fromJson()`, and
conversion to `VerseRef`. Model values and nested collections are immutable;
construct a new value with `copyWith()` instead of mutating shared state.

## Navigation

```dart
final genesis = bible[BibleBookEnum.genesis] as Book;
final genesis1 = bible[(BibleBookEnum.genesis, 1)] as Chapter;
final genesis11 = bible[(BibleBookEnum.genesis, 1, 1)] as Verse;

final current = genesis11.location;
final next = bible.nextVerse(current);
final previous = bible.previousVerse(current);
```

Navigation follows the edition's declared `bookOrder` and actual chapter and
verse numbers. Sparse numbering is supported.

## References and rich passages

Reference parsing is multilingual by default. The loaded language and custom
book names are preferences, while a concrete `inputLanguage` makes parsing
strict:

```dart
final parsed = bible.parseReference('Juan 3:16');
if (parsed case ParseSuccess(value: final reference)) {
  print(bible.resolveReference(reference).single.text);
}

final spanish = bible.getVerseByRef(
  'Juan 3:16',
  inputLanguage: BibleLanguageEnum.spanish,
);
```

The 1.1 reference grammar supports verse lists, chapter ranges,
semicolon-separated sequences, and cross-book ranges:

```dart
final selection = bible.getPassage(
  'John 3:16,18-20; Acts 2:1-4; Romans 8',
);
final crossBook = bible.getVerseRangeByRef('John 21:25-Acts 1:2');

final osis = referenceFromOsisIdentifier('John.3.16');
final verse = bible.resolveReference(osis).single;
```

## Search

`search()` is a fast all-terms search, not an exact phrase search:

```dart
final verses = bible.search('faith hope');
```

Use `SearchOptions` for explicit modes, scope, normalization, and pagination:

```dart
final page = bible.searchWithOptions(
  'creacion',
  SearchOptions(
    mode: SearchMode.any,
    wholeWords: false,
    ignoreDiacritics: true,
    offset: 20,
    maxResults: 20,
  ),
);

print('Showing ${page.count} results; more: ${page.hasMore}');
print('Next offset: ${page.nextOffset}');
```

Canonical NFC normalization is enabled by default, so equivalent NFC and NFD
text matches consistently. Diacritics remain meaningful unless
`ignoreDiacritics` is enabled; that option also removes Hebrew niqqud and
Arabic harakat. All/any search can match query substrings in scripts commonly
written without spaces, including Chinese, Japanese, Thai, Lao, Khmer, and
Myanmar. Set `wholeWords: true` when exact token boundaries are required.

Search hits are ready for highlighted UI rendering:

```dart
for (final hit in page.hits) {
  print('${hit.reference}: ${hit.snippet}');
  print(hit.snippetMatchRanges); // Offsets relative to hit.snippet.
  print(hit.matchRanges);        // Offsets relative to hit.verse.text.
}
```

`snippetStart` and `snippetEnd` locate the snippet within the full verse.
Cropping respects grapheme boundaries.

Typo-tolerant search uses bounded Unicode edit distance and the same
normalization, multi-term modes, pagination, and unspaced-script substring
behavior:

```dart
final fuzzy = bible.fuzzySearch(
  'beginnig creatd',
  maxDistance: 1,
  mode: SearchMode.all,
  maxResults: 20,
);
```

## Validation and errors

Decoded content is strict by default: it must contain books, chapters, verses,
and non-blank verse text. Malformed data throws `BibleDataFormatError` with a
stable code and JSON path instead of leaking cast or parser errors.

Intentionally partial content can opt into the compatibility policy:

```dart
final partial = Bible.fromDecodedJson(
  data,
  options: const BibleLoadOptions(
    validation: BibleDataValidationOptions.permissive,
  ),
);
```

Permissive validation allows skeletal content; it does not accept malformed
types, invalid identifiers, duplicate locations, or non-positive numbers.

For ordinary lookup failures at application boundaries, use result helpers:

```dart
final result = bible.getVerseResult(BibleBookEnum.genesis, 1, 1);

switch (result) {
  case Success(value: final verse):
    print(verse.text);
  case Failure(error: final error):
    print(error);
}
```

## Translation catalogs and metadata

`BibleCatalog` validates unique, non-blank source IDs and supports list- or
map-shaped catalogs:

```dart
final catalog = BibleCatalog.fromDecodedJson(catalogJson);
final englishSources = catalog.forLanguage('en');
final source = catalog.findById('eng-kjv-1769');
```

Metadata includes edition identity, language, display name, abbreviation,
direction, copyright, content license, canon, and version date. Unknown
JSON-compatible metadata and nested source fields are retained at their
original levels for round-tripping.

## Content schema

Schema version 1 adds explicit `bookOrder`, edition identity, and optional
annotations while accepting the original plain-string verse format. See the
[content schema](doc/content_schema.md) for the full contract and migration
guidance.

## Statistics and diagnostics

```dart
print(bible.stats);
print(bible.getBook(BibleBookEnum.genesis).stats);
print(bible.getChapter(BibleBookEnum.genesis, 1).stats);
print(bible.performanceMetrics);
```

Performance metrics report content size and retained-index state as estimates;
they are diagnostics, not heap-profiler measurements.

## Licensing

Bible IO source code is intentionally licensed under the
[GNU Affero General Public License v3 or later](LICENSE-NOTICE.md)
(`AGPL-3.0-or-later`) so improvements to Bible software remain free, including
software offered over a network.

Bible translations, study notes, footnotes, and other content loaded by the
package are independent works. Their copyright and license are not changed by
the package's code license. Applications and data distributors must obtain and
honor the rights for each content edition; use metadata `copyright` and
`license` fields to carry that information with the edition.

## Development and release checks

```bash
dart format --output=none --set-exit-if-changed lib bin example test
dart analyze
dart test
mkdir -p build/web
dart compile js example/bible_io_example.dart -o build/web/example.js
dart pub publish --dry-run
```

Run the conventional example with:

```bash
dart run example/bible_io_example.dart
```
