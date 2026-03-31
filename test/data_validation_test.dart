import 'package:bible_io/bible_io.dart';
import 'package:test/test.dart';

void main() {
  late Bible bible;

  setUp(() async {
    // Use the real KJV Bible JSON file for testing
    bible = await Bible.load('test/bible_versions/en_kjv.json');
  });

  group('Data validation', () {
    test('Bible data has correct structure', () {
      expect(bible.books.length, 66); // KJV has 66 books
      expect(bible.books.every((book) => book.chapters.isNotEmpty), isTrue);
      expect(bible.books.every((book) => book.chapters.every((chapter) => chapter.verses.isNotEmpty)), isTrue);
    });

    test('Book data is valid', () {
      for (final book in bible.books) {
        expect(book.name, isNotEmpty);
        expect(book.bookEnum, isNotNull);
        expect(book.chapters.length, greaterThan(0));
      }
    });

    test('Chapter data is valid', () {
      for (final book in bible.books) {
        for (final chapter in book.chapters) {
          expect(chapter.chapterNumber, greaterThan(0));
          expect(chapter.verses.length, greaterThan(0));
          expect(chapter.book, book.bookEnum);
        }
      }
    });

    test('Verse data is valid', () {
      for (final book in bible.books) {
        for (final chapter in book.chapters) {
          for (final verse in chapter.verses) {
            expect(verse.verseNumber, greaterThan(0));
            expect(verse.text, isNotEmpty);
            expect(verse.chapterNumber, chapter.chapterNumber);
            expect(verse.book, book.bookEnum);
          }
        }
      }
    });

    test('Verse numbers are sequential within chapters', () {
      for (final book in bible.books) {
        for (final chapter in book.chapters) {
          final verseNumbers = chapter.verses.map((v) => v.verseNumber).toList();
          for (int i = 0; i < verseNumbers.length - 1; i++) {
            expect(verseNumbers[i + 1], verseNumbers[i] + 1);
          }
        }
      }
    });
  });
}