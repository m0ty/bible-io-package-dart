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
    test('returns no results for blank queries or non-positive limits', () {
      final bible = bibleWithText('beginning');

      expect(bible.fuzzySearch('   '), isA<SearchResults>());
      expect(bible.fuzzySearch('   ').isEmpty, isTrue);
      expect(bible.fuzzySearch('beginning', maxResults: 0).isEmpty, isTrue);
      expect(bible.fuzzySearch('beginning', maxResults: -1).isEmpty, isTrue);
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
  });

  group('Verse text helpers', () {
    test('words extracts Unicode letters, marks, and numbers', () {
      final verse = Verse(book, 1, 1, 'בְּרֵאשִׁית, κόσμος १२३—grace!');

      expect(verse.words, ['בְּרֵאשִׁית', 'κόσμος', '१२३', 'grace']);
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
