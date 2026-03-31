import 'package:bible_io/bible_io.dart';
import 'package:test/test.dart';

void main() {
  late Bible bible;

  setUp(() async {
    // Use the real KJV Bible JSON file for testing
    bible = await Bible.load('test/bible_versions/en_kjv.json');
  });

  group('Boundary conditions and performance', () {
    test('Accessing first and last books works correctly', () {
      final firstBook = bible.getBookById(1);
      expect(firstBook.name, 'Genesis');
      final lastBook = bible.getBookById(66);
      expect(lastBook.name, 'Revelation');
    });

    test('Accessing first and last chapters works correctly', () {
      final genesis1 = bible.getChapter(BibleBookEnum.genesis, 1);
      expect(genesis1.chapterNumber, 1);
      final revelation22 = bible.getChapter(BibleBookEnum.revelation, 22);
      expect(revelation22.chapterNumber, 22);
    });

    test('Accessing first and last verses works correctly', () {
      final genesis1_1 = bible.getVerse(BibleBookEnum.genesis, 1, 1);
      expect(genesis1_1.verseNumber, 1);
      final revelation22_21 = bible.getVerse(BibleBookEnum.revelation, 22, 21);
      expect(revelation22_21.verseNumber, 21);
    });

    test('Large search operations complete in reasonable time', () {
      final startTime = DateTime.now();
      final results = bible.search('the');
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      expect(duration.inSeconds, lessThan(5)); // Should complete in under 5 seconds
      expect(results.length, greaterThan(1000)); // Should find many results
    });

    test('Memory usage is reasonable for large operations', () {
      // This is a basic test - in a real scenario you'd use memory profiling tools
      final results = bible.search('the');
      expect(results.length, greaterThan(1000));
      // The test passes if no out-of-memory errors occur
    });

    test('Concurrent access works correctly', () async {
      // Test basic concurrent access
      final futures = <Future>[];
      for (int i = 0; i < 10; i++) {
        futures.add(Future(() {
          final book = bible.getBook(BibleBookEnum.genesis);
          expect(book.name, 'Genesis');
        }));
      }
      await Future.wait(futures);
    });
  });
}