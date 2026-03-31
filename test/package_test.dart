import 'package:bible_io/bible_io.dart';
import 'package:test/test.dart';

void main() {
  group('Bible', () {
    late Bible bible;

    setUp(() async {
      // Use the real KJV Bible JSON file for testing
      bible = await Bible.load('test/bible_versions/en_kjv.json');
    });

    test('loads books correctly', () {
      expect(bible.books.length, 66);
      expect(bible.language, isNotNull);
    });

    test('getBook works', () {
      final genesis = bible.getBook(BibleBookEnum.genesis);
      expect(genesis.name, 'Genesis');
      expect(genesis.chapters.length, 50);
    });

    test('getVerse works', () {
      final verse = bible.getVerse(BibleBookEnum.genesis, 1, 1);
      expect(verse.text, 'In the beginning God created the heaven and the earth.');
    });

    test('search works', () {
      final verses = bible.search('God');
      expect(verses.length, greaterThan(1000)); // "God" appears many times in KJV
    });

    test('getByRef works for verse', () {
      final result = bible.getByRef('Genesis 1:1');
      expect(result, isA<Verse>());
      if (result is Verse) {
        expect(result.text, 'In the beginning God created the heaven and the earth.');
      }
    });
  });
}
