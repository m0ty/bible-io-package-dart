import 'package:bible_io/src/book.dart';
import 'package:bible_io/src/chapter.dart';
import 'package:bible_io/src/search.dart';
import 'package:bible_io/src/text_search.dart';
import 'package:bible_io/src/verse.dart';
import 'package:bible_io_references/bible_io_references.dart';
import 'package:test/test.dart';

void main() {
  group('SearchOptions', () {
    test('retains const construction for source compatibility', () {
      const options = SearchOptions(mode: SearchMode.all, maxResults: 10);

      expect(options.mode, SearchMode.all);
      expect(options.maxResults, 10);
    });

    test('validates values in runtime and has value semantics', () {
      final first = SearchOptions(
        mode: SearchMode.all,
        maxResults: 20,
        offset: 5,
        book: BibleBookEnum.genesis,
        chapter: 1,
        normalizeUnicode: false,
        ignoreDiacritics: true,
      );
      final second = SearchOptions(
        mode: SearchMode.all,
        maxResults: 20,
        offset: 5,
        book: BibleBookEnum.genesis,
        chapter: 1,
        normalizeUnicode: false,
        ignoreDiacritics: true,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(
        () => SearchOptions.checked(maxResults: -1),
        throwsArgumentError,
      );
      expect(() => SearchOptions.checked(offset: -1), throwsArgumentError);
      expect(() => SearchOptions.checked(chapter: 0), throwsArgumentError);
      expect(() => SearchOptions.checked(verse: 0), throwsArgumentError);
    });

    test('copyWith replaces, preserves, and explicitly clears fields', () {
      final options = SearchOptions(
        maxResults: 10,
        book: BibleBookEnum.genesis,
        chapter: 2,
      );

      expect(options.copyWith(offset: 4).maxResults, 10);
      expect(options.copyWith(offset: 4).offset, 4);
      expect(options.copyWith(maxResults: null).maxResults, isNull);
      expect(options.copyWith(book: null).book, isNull);
      expect(options.copyWith(chapter: null).chapter, isNull);
      expect(() => options.copyWith(maxResults: 'ten'), throwsArgumentError);
    });
  });

  group('SearchHit', () {
    late Verse verse;
    late Book book;

    setUp(() {
      verse = Verse(BibleBookEnum.genesis, 1, 1, '0123456789abcdefghijklmnop');
      book = Book(BibleBookEnum.genesis, [
        Chapter(BibleBookEnum.genesis, 1, [verse]),
      ]);
    });

    test('provides source-relative and snippet-relative ranges', () {
      final hit = SearchHit(
        verse: verse,
        book: book,
        matchRanges: [TextRange(start: 2, end: 5), TextRange(start: 7, end: 9)],
        snippetStart: 3,
        snippetEnd: 8,
      );

      expect(hit.snippet, '34567');
      expect(hit.snippetStart, 3);
      expect(hit.snippetEnd, 8);
      expect(hit.snippetMatchRanges, [
        TextRange(start: 0, end: 2),
        TextRange(start: 4, end: 5),
      ]);
      expect(hit.hasLeadingOmission, isTrue);
      expect(hit.hasTrailingOmission, isTrue);
    });

    test('context snippets are exact, grapheme-safe source slices', () {
      final markedVerse = Verse(
        BibleBookEnum.genesis,
        1,
        2,
        'prefix e\u0301 suffix and more text',
      );
      final markedBook = Book(BibleBookEnum.genesis, [
        Chapter(BibleBookEnum.genesis, 1, [markedVerse]),
      ]);
      final hit = SearchHit.withContext(
        verse: markedVerse,
        book: markedBook,
        matchRanges: [TextRange(start: 7, end: 9)],
        maxSnippetLength: 8,
      );

      expect(
        hit.snippet,
        markedVerse.text.substring(hit.snippetStart, hit.snippetEnd),
      );
      expect(hit.snippet.startsWith('\u0301'), isFalse);
      expect(hit.snippetMatchRanges, isNotEmpty);
    });

    test('rejects inconsistent books, ranges, snippets, and bounds', () {
      final otherVerse = Verse(
        BibleBookEnum.genesis,
        1,
        1,
        '${verse.text}!',
      );
      expect(
        () => SearchHit(verse: otherVerse, book: book),
        throwsArgumentError,
      );
      expect(
        () => SearchHit(
          verse: verse,
          book: book,
          matchRanges: [TextRange(start: 0, end: verse.text.length + 1)],
        ),
        throwsArgumentError,
      );
      expect(
        () => SearchHit(
          verse: verse,
          book: book,
          matchRanges: [
            TextRange(start: 3, end: 6),
            TextRange(start: 5, end: 7),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => SearchHit(verse: verse, book: book, snippet: '...345...'),
        throwsArgumentError,
      );
      expect(
        () =>
            SearchHit(verse: verse, book: book, snippetStart: 4, snippetEnd: 3),
        throwsArgumentError,
      );
    });
  });

  group('SearchResults', () {
    test('exposes validated pagination and value metadata', () {
      final first = Verse(BibleBookEnum.genesis, 1, 1, 'one');
      final second = Verse(BibleBookEnum.genesis, 1, 2, 'two');
      final results = SearchResults(
        'query',
        [first, second],
        offset: 2,
        limit: 2,
        totalCount: 5,
      );
      final equivalent = SearchResults(
        'query',
        [
          Verse(BibleBookEnum.genesis, 1, 1, 'one'),
          Verse(BibleBookEnum.genesis, 1, 2, 'two'),
        ],
        offset: 2,
        limit: 2,
        totalCount: 5,
      );

      expect(results, equivalent);
      expect(results.hasPrevious, isTrue);
      expect(results.hasMore, isTrue);
      expect(results.nextOffset, 4);
      expect(() => results.verses.add(first), throwsUnsupportedError);

      final empty = SearchResults(
        'none',
        const [],
        offset: 10,
        totalCount: 0,
      );
      expect(empty.hasPrevious, isFalse);
    });

    test('rejects invalid pages and duplicate locations', () {
      final verse = Verse(BibleBookEnum.genesis, 1, 1, 'one');
      expect(
        () => SearchResults('q', [verse], offset: -1),
        throwsArgumentError,
      );
      expect(() => SearchResults('q', [verse], limit: 0), throwsArgumentError);
      expect(
        () => SearchResults('q', [verse], totalCount: 1, hasMore: true),
        throwsArgumentError,
      );
      expect(
        () => SearchResults('q', [
          verse,
          Verse(BibleBookEnum.genesis, 1, 1, 'duplicate'),
        ]),
        throwsArgumentError,
      );
    });
  });

  group('Unicode text search utilities', () {
    test('matches NFC and NFD and maps matches to source offsets', () {
      const source = 'Cafe\u0301 society';

      expect(containsNormalizedText(source, 'CAFÉ'), isTrue);
      expect(findNormalizedSubstringRanges(source, 'fé'), [
        TextRange(start: 2, end: 5),
      ]);
      expect(tokenizeSearchText(source).first, normalizeSearchText('Café'));
    });

    test('diacritic folding remains explicitly opt-in', () {
      expect(containsNormalizedText('café', 'cafe'), isFalse);
      expect(
        containsNormalizedText('café', 'cafe', ignoreDiacritics: true),
        isTrue,
      );
      expect(normalizeSearchText('בָּרָא', ignoreDiacritics: true), 'ברא');
    });

    test('applies multi-character and special Unicode case folds', () {
      expect(containsNormalizedText('Straße', 'STRASSE'), isTrue);
      expect(containsNormalizedText('κόσμος', 'ΚΌΣΜΟΣ'), isTrue);
      expect(containsNormalizedText('ſcripture', 'SCRIPTURE'), isTrue);
    });

    test('supports substring terms in Chinese, Japanese, and Thai', () {
      final allTerms = SearchOptions(mode: SearchMode.all);

      expect(matchesSearchText('起初神创造天地', '创造', allTerms), isTrue);
      expect(matchesSearchText('神は天地を創造された', '天地', allTerms), isTrue);
      expect(
        matchesSearchText('พระเจ้าทรงสร้างฟ้าสวรรค์', 'สร้าง', allTerms),
        isTrue,
      );
      expect(matchesSearchText('a scatter pattern', 'cat', allTerms), isFalse);
      expect(
        matchesSearchText('起初神创造天地', '创造', allTerms.copyWith(wholeWords: true)),
        isFalse,
      );
    });

    test('builds compact lookup keys for unspaced scripts', () {
      final terms = buildSearchIndexTerms('起初神创造天地');

      expect(terms, contains('创造'));
      expect(searchIndexLookupKey('创造天地'), '创造天');
      expect(searchIndexLookupKey('beginning'), 'beginning');
    });

    test('bounded Levenshtein uses Unicode scalar values', () {
      expect(isWithinLevenshteinDistance('a😀b', 'ab', 1), isTrue);
      expect(isWithinLevenshteinDistance('kitten', 'sitting', 2), isFalse);
      expect(isWithinLevenshteinDistance('kitten', 'sitting', 3), isTrue);
      expect(isWithinLevenshteinDistance('same', 'same', 0), isTrue);
      expect(
        () => isWithinLevenshteinDistance('a', 'b', -1),
        throwsArgumentError,
      );
    });

    test('bounded Levenshtein agrees with full DP for short strings', () {
      final samples = _shortStrings(['a', 'b', '😀'], 3);
      for (final first in samples) {
        for (final second in samples) {
          final expectedDistance = _referenceLevenshtein(first, second);
          for (var bound = 0; bound <= 3; bound++) {
            expect(
              isWithinLevenshteinDistance(first, second, bound),
              expectedDistance <= bound,
              reason: '$first / $second with bound $bound',
            );
          }
        }
      }
    });
  });
}

List<String> _shortStrings(List<String> alphabet, int maximumLength) {
  var current = <String>[''];
  final all = <String>[''];
  for (var length = 1; length <= maximumLength; length++) {
    current = [
      for (final prefix in current)
        for (final character in alphabet) '$prefix$character',
    ];
    all.addAll(current);
  }
  return all;
}

int _referenceLevenshtein(String first, String second) {
  final firstRunes = first.runes.toList(growable: false);
  final secondRunes = second.runes.toList(growable: false);
  final matrix = List.generate(
    firstRunes.length + 1,
    (row) => List<int>.filled(secondRunes.length + 1, 0),
  );
  for (var row = 0; row <= firstRunes.length; row++) {
    matrix[row][0] = row;
  }
  for (var column = 0; column <= secondRunes.length; column++) {
    matrix[0][column] = column;
  }
  for (var row = 1; row <= firstRunes.length; row++) {
    for (var column = 1; column <= secondRunes.length; column++) {
      final deletion = matrix[row - 1][column] + 1;
      final insertion = matrix[row][column - 1] + 1;
      final substitution = matrix[row - 1][column - 1] +
          (firstRunes[row - 1] == secondRunes[column - 1] ? 0 : 1);
      matrix[row][column] = [deletion, insertion, substitution].reduce(
        (minimum, candidate) => candidate < minimum ? candidate : minimum,
      );
    }
  }
  return matrix[firstRunes.length][secondRunes.length];
}
