import 'package:bible_io/bible_io.dart';
import 'package:test/test.dart';

void main() {
  late Bible bible;

  setUp(() async {
    // Use the real KJV Bible JSON file for testing
    bible = await Bible.load('test/bible_versions/en_kjv.json');
  });

  group('Chapter access and navigation', () {
    test('getChapter returns correct chapter', () {
      final genesis1 = bible.getChapter(BibleBookEnum.genesis, 1);
      expect(genesis1.book.fullName, 'Genesis');
      expect(genesis1.chapterNumber, 1);
      expect(genesis1.verses.length, 31); // Genesis 1 has 31 verses in KJV
    });

    test('getChapter throws ChapterNotFoundError for non-existent chapter', () {
      expect(() => bible.getChapter(BibleBookEnum.genesis, 51), throwsA(isA<ChapterNotFoundError>()));
    });

    test('chapters property returns all chapters for a book', () {
      final genesis = bible.getBook(BibleBookEnum.genesis);
      expect(genesis.chapters.length, 50);
      expect(genesis.chapters.first.chapterNumber, 1);
      expect(genesis.chapters.last.chapterNumber, 50);
    });
  });
}