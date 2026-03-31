import 'package:bible_io/bible_io.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  late Bible bible;

  setUpAll(() async {
    // Load Bible once for all tests in this group
    bible = await BibleTestFixture.getBible();
  });

  group('Reference parsing', () {
    test('getVerseByRef parses single verse reference', () {
      final verse = bible.getVerseByRef('Genesis 1:1');
      expect(verse.text, 'In the beginning God created the heaven and the earth.');
    });

    test('getByRef single verse string returns Verse', () {
      final result = bible.getByRef('Genesis 1:1');
      expect(result, isA<Verse>());
      if (result is Verse) {
        expect(result.text, 'In the beginning God created the heaven and the earth.');
      }
    });

    test('getVerseRangeByRef same chapter', () {
      final verses = bible.getVerseRangeByRef('Genesis 1:1-3');
      expect(verses.length, 3);
      expect(verses[0].verseNumber, 1);
      expect(verses[2].verseNumber, 3);
    });

    test('getVerseRangeByRef multiple chapters', () {
      final verses = bible.getVerseRangeByRef('Genesis 1:3-2:2');
      expect(verses.length, 31); // Genesis 1:3-31 (29 verses) + Genesis 2:1-2 (2 verses)
      expect(verses[0].chapterNumber, 1);
      expect(verses[0].verseNumber, 3);
      expect(verses[28].chapterNumber, 1); // Last verse of chapter 1
      expect(verses[28].verseNumber, 31);
      expect(verses[29].chapterNumber, 2); // First verse of chapter 2
      expect(verses[29].verseNumber, 1);
      expect(verses[30].chapterNumber, 2); // Last verse in range
      expect(verses[30].verseNumber, 2);
    });

    test('getByRef range string returns List<Verse>', () {
      final result = bible.getByRef('Genesis 1:1-3');
      expect(result, isA<List<Verse>>());
      if (result is List<Verse>) {
        expect(result.length, 3);
      }
    });
  });
}