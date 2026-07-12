import 'package:bible_io/bible_io.dart';
import 'package:test/test.dart';

void main() {
  late Bible bible;

  setUpAll(() async {
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
      final stopwatch = Stopwatch()..start();
      final results = bible.search('the');
      stopwatch.stop();
      expect(
        stopwatch.elapsed.inSeconds,
        lessThan(5),
      ); // Should complete in under 5 seconds
      expect(results.length, greaterThan(1000)); // Should find many results
    });

    test('Performance metrics report populated index and memory estimates', () {
      final metrics = bible.performanceMetrics;

      expect(metrics.searchIndexSize, greaterThan(0));
      expect(metrics.memoryUsage, greaterThan(0));
      expect(metrics.loadTime, isNot(Duration.zero));
    });

    test('Concurrent access works correctly', () async {
      final futures = <Future>[];
      for (int i = 0; i < 10; i++) {
        futures.add(
          Future(() {
            final book = bible.getBook(BibleBookEnum.genesis);
            expect(book.name, 'Genesis');
          }),
        );
      }
      await Future.wait(futures);
    });
  });
}
