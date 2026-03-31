import 'package:bible_io/bible_io.dart';
import 'package:test/test.dart';

void main() {
  late Bible bible;

  setUp(() async {
    // Use the real KJV Bible JSON file for testing
    bible = await Bible.load('test/bible_versions/en_kjv.json');
  });

  group('Verse access and navigation', () {
    test('getVerse returns correct verse', () {
      final genesis1_1 = bible.getVerse(BibleBookEnum.genesis, 1, 1);
      expect(genesis1_1.book.fullName, 'Genesis');
      expect(genesis1_1.chapterNumber, 1);
      expect(genesis1_1.verseNumber, 1);
      expect(genesis1_1.text, startsWith('In the beginning'));
    });

    test('getVerse throws VerseNotFoundError for non-existent verse', () {
      expect(() => bible.getVerse(BibleBookEnum.genesis, 1, 32), throwsA(isA<VerseNotFoundError>()));
    });

    test('getVerses returns all verses in chapter', () {
      final verses = bible.getVerses(BibleBookEnum.genesis, 1);
      expect(verses.length, 31);
      expect(verses.first.verseNumber, 1);
      expect(verses.last.verseNumber, 31);
    });
  });
}