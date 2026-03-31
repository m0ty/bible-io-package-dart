import 'package:bible_io/bible_io.dart';
import 'package:test/test.dart';

void main() {
  late Bible bible;

  setUp(() async {
    // Use the real KJV Bible JSON file for testing
    bible = await Bible.load('test/bible_versions/en_kjv.json');
  });

  group('Search functionality', () {
    test('search returns verses containing the search term', () {
      final results = bible.search('beginning');
      expect(results.isNotEmpty, isTrue);
      expect(results.first.text, contains('beginning'));
    });

    test('search is case insensitive', () {
      final results = bible.search('BEGINNING');
      expect(results.isNotEmpty, isTrue);
      expect(results.first.text.toLowerCase(), contains('beginning'));
    });

    test('search returns empty list for non-existent term', () {
      final results = bible.search('nonexistentword12345');
      expect(results, isEmpty);
    });

    test('search returns multiple results for common words', () {
      final results = bible.search('the');
      expect(results.length, greaterThan(1));
    });

    test('search results contain correct verse information', () {
      final results = bible.search('In the beginning');
      expect(results.isNotEmpty, isTrue);
      final firstResult = results.first;
      expect(firstResult.book.fullName, 'Genesis');
      expect(firstResult.chapterNumber, 1);
      expect(firstResult.verseNumber, 1);
    });
  });
}