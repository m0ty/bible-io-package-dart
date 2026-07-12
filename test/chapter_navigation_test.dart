import 'package:bible_io/bible_io.dart';
import 'package:test/test.dart';

void main() {
  late Bible bible;

  setUpAll(() async {
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
      expect(
        () => bible.getChapter(BibleBookEnum.genesis, 51),
        throwsA(isA<ChapterNotFoundError>()),
      );
    });

    test('chapters property returns all chapters for a book', () {
      final genesis = bible.getBook(BibleBookEnum.genesis);
      expect(genesis.chapters.length, 50);
      expect(genesis.chapters.first.chapterNumber, 1);
      expect(genesis.chapters.last.chapterNumber, 50);
    });

    test('nextChapter and previousChapter move across book boundaries', () {
      expect(
        bible.nextChapter(
          const BibleLocation(book: BibleBookEnum.genesis, chapter: 1),
        ),
        const BibleLocation(book: BibleBookEnum.genesis, chapter: 2),
      );
      expect(
        bible.nextChapter(
          const BibleLocation(book: BibleBookEnum.genesis, chapter: 50),
        ),
        const BibleLocation(book: BibleBookEnum.exodus, chapter: 1),
      );
      expect(
        bible.previousChapter(
          const BibleLocation(book: BibleBookEnum.exodus, chapter: 1),
        ),
        const BibleLocation(book: BibleBookEnum.genesis, chapter: 50),
      );
      expect(
        bible.previousChapter(
          const BibleLocation(book: BibleBookEnum.genesis, chapter: 1),
        ),
        isNull,
      );
    });

    test('location helpers validate chapters and verses', () {
      const chapter = BibleLocation(book: BibleBookEnum.john, chapter: 3);
      const verse = BibleLocation(
        book: BibleBookEnum.john,
        chapter: 3,
        verse: 16,
      );

      expect(bible.hasNextChapter(chapter), isTrue);
      expect(bible.hasPreviousChapter(chapter), isTrue);
      expect(bible.getChapterAt(chapter).chapterNumber, 3);
      expect(bible.getVerseAt(verse).text, contains('God so loved'));
      expect(bible.containsReference(verse), isTrue);
      expect(
        bible.containsReference(
          const BibleLocation(book: BibleBookEnum.john, chapter: 999),
        ),
        isFalse,
      );
    });
  });
}
