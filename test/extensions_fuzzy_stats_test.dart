import 'package:bible_io/bible_io.dart';
import 'package:test/test.dart';

void main() {
  final book = BibleBookEnum.genesis;

  Bible bibleWithText(String text) {
    final verse = Verse(book, 1, 1, text);
    final chapter = Chapter(book, 1, [verse]);
    return Bible.fromBooks([
      Book(book, [chapter]),
    ]);
  }

  group('fuzzySearch', () {
    test('handles blank queries and validates result limits', () {
      final bible = bibleWithText('beginning');

      expect(bible.fuzzySearch('   '), isA<SearchResults>());
      expect(bible.fuzzySearch('   ').isEmpty, isTrue);
      final zeroSizedPage = bible.fuzzySearch('beginning', maxResults: 0);
      expect(zeroSizedPage.isEmpty, isTrue);
      expect(zeroSizedPage.hasMore, isTrue);
      expect(
        () => bible.fuzzySearch('beginning', maxResults: -1),
        throwsArgumentError,
      );
    });

    test('rejects a negative maximum distance', () {
      final bible = bibleWithText('beginning');

      expect(
        () => bible.fuzzySearch('beginning', maxDistance: -1),
        throwsArgumentError,
      );
    });

    test('matches Unicode words containing combining marks and numbers', () {
      final bible = bibleWithText('בְּרֵאשִׁית १२३');

      expect(bible.fuzzySearch('בְּרֵאשִׁית', maxDistance: 0).count, 1);
      expect(bible.fuzzySearch('१२३', maxDistance: 0).count, 1);
    });

    test('measures edits in Unicode scalar values', () {
      final bible = bibleWithText('a𐐀b');

      expect(bible.fuzzySearch('ab', maxDistance: 1).count, 1);
      expect(bible.fuzzySearch('ab', maxDistance: 0).isEmpty, isTrue);
    });

    test('normalizes canonical equivalents and optionally folds marks', () {
      final bible = bibleWithText('Cafe\u0301 בָּרָא');

      expect(bible.fuzzySearch('café', maxDistance: 0).count, 1);
      expect(bible.fuzzySearch('ברא', maxDistance: 0).isEmpty, isTrue);
      expect(
        bible.fuzzySearch('ברא', maxDistance: 0, ignoreDiacritics: true).count,
        1,
      );
    });

    test('supports all, any, and ordered multi-term semantics', () {
      final bible = bibleWithText('In the beginning God created heaven');

      expect(bible.fuzzySearch('beginnig creatd', maxDistance: 1).count, 1);
      expect(
        bible
            .fuzzySearch('missing creatd', maxDistance: 1, mode: SearchMode.any)
            .count,
        1,
      );
      expect(
        bible
            .fuzzySearch(
              'beginning created',
              maxDistance: 0,
              mode: SearchMode.exact,
            )
            .isEmpty,
        isTrue,
      );
      expect(
        bible
            .fuzzySearch('God created', maxDistance: 0, mode: SearchMode.exact)
            .count,
        1,
      );
    });

    test('matches fuzzy substrings in commonly unspaced scripts', () {
      final bible = bibleWithText('èµ·åˆç¥žåˆ›é€ å¤©åœ°');

      expect(bible.fuzzySearch('åˆ›é€ ', maxDistance: 0).count, 1);
      expect(bible.fuzzySearch('åˆ›é€ ', maxDistance: 1).count, 1);
    });

    test('returns ranges and pagination metadata', () {
      final verses = [
        Verse(book, 1, 1, 'beginning'),
        Verse(book, 1, 2, 'beginning'),
        Verse(book, 1, 3, 'beginning'),
      ];
      final bible = Bible.fromBooks([
        Book(book, [Chapter(book, 1, verses)]),
      ]);

      final results = bible.fuzzySearch(
        'begining',
        maxDistance: 1,
        maxResults: 1,
        offset: 1,
      );

      expect(results.verses.single.verseNumber, 2);
      expect(results.offset, 1);
      expect(results.limit, 1);
      expect(results.hasMore, isTrue);
      expect(results.nextOffset, 2);
      expect(results.hits.single.matchRanges, isNotEmpty);
      expect(results.hits.single.snippetMatchRanges, isNotEmpty);

      final finalPage = bible.fuzzySearch(
        'begining',
        maxDistance: 1,
        maxResults: 2,
        offset: 2,
      );
      expect(finalPage.totalCount, 3);
      expect(finalPage.hasMore, isFalse);
    });
  });

  group('Verse text helpers', () {
    test('words extracts Unicode letters, marks, and numbers', () {
      final verse = Verse(
        book,
        1,
        1,
        "בְּרֵאשִׁית, κόσμος १२३—grace! sister's",
      );

      expect(verse.words, [
        'בְּרֵאשִׁית',
        'κόσμος',
        '१२३',
        'grace',
        'sister',
        's',
      ]);
    });

    test('averageWordLength averages token lengths only', () {
      final verse = Verse(book, 1, 1, 'one, three!');

      expect(verse.stats.wordCount, 2);
      expect(verse.stats.averageWordLength, 4);
    });

    test('averageWordLength is zero when there are no tokens', () {
      final verse = Verse(book, 1, 1, ' — !!! ');

      expect(verse.stats.averageWordLength, 0);
    });
  });
}
