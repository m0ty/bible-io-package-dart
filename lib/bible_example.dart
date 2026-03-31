import 'package:bible_io/bible_io.dart';
import 'src/extensions.dart'; // Explicit import for extensions

/// Example usage of bible_io package showcasing modern Dart features.
Future<void> bibleExample() async {
  print('🚀 Loading Bible with progress tracking...');

  // 1. ASYNC LOADING with progress (Modern Dart)
  final bible = await Bible.load(
    'test/bible_versions/en_kjv.json',
    onProgress: (progress) => print('📖 Loading: ${(progress * 100).round()}%'),
  );

  print('✅ Bible loaded! Performance: ${bible.performanceMetrics}');

  // 2. FUZZY SEARCH (New feature!)
  print('\n🔍 Fuzzy search for "begnning" (typo):');
  final fuzzyResults = bible.fuzzySearch('begnning', maxDistance: 2, maxResults: 3);
  print('Found ${fuzzyResults.verses.length} verses with fuzzy match');

  // 3. JSON EXPORT (New feature!)
  print('\n💾 Exporting Bible to JSON...');
  final jsonExport = bible.toJson();
  print('📄 Exported ${jsonExport.length} characters of JSON');

  // 4. OPERATOR OVERLOADING (Dart-like syntax)
  final genesis = bible[BibleBookEnum.genesis]; // bible[book]
  final chapter1 = bible[(BibleBookEnum.genesis, 1)]; // bible[(book, chapter)]
  final verse = bible[(BibleBookEnum.genesis, 1, 1)]; // bible[(book, chapter, verse)]

  // 5. RESULT TYPES (Functional error handling)
  final result = bible.getVerseResult(BibleBookEnum.genesis, 1, 1);
  if (result.isSuccess) {
    print('Verse: ${result.value.text}');
  } else {
    print('Error: ${result.error}');
  }

  // 4. EXTENSION METHODS (Fluent API)
  final searchResults = bible.searchAdvanced(text: 'God', wholeWords: true, maxResults: 10);
  print('Found ${searchResults.count} verses containing "God"');

  // 5. RECORDS AND MODERN TYPES
  final reference = (book: BibleBookEnum.genesis, chapter: 1, verse: 1);

  // 6. FUNCTIONAL PROGRAMMING
  final allVerses = bible.allVerses;
  final longVerses = allVerses.where((v) => v.length > 200);
  final wordCount = allVerses.fold<int>(0, (sum, verse) => sum + verse.words.length);

  // 7. NULL SAFETY
  final safeVerse = bible.verseOrNull('Genesis 1:1');
  final safeVerses = bible.versesOrNull('Genesis 1:1-3');

  // 8. STATISTICS AND ANALYTICS
  print('Bible stats: ${bible.stats}');
  // print('Genesis stats: ${genesis.stats}'); // TODO: Debug extension issue

  // 9. ADVANCED SEARCH
  final advancedSearch = bible.searchAdvanced(
    text: 'love',
    book: BibleBookEnum.john,
    caseSensitive: false,
    maxResults: 5,
  );

  // 10. GROUPING AND ANALYSIS
  final byBook = searchResults.byBook;
  for (final entry in byBook.entries) {
    print('${entry.key.fullName}: ${entry.value.length} verses');
  }

  // 11. CHAINING OPERATIONS (Fluent)
  final result2 = bible
      .getVerseByRefResult('John 3:16')
      .map((verse) => verse.text.toUpperCase())
      .getOrElse('Verse not found');

  print('John 3:16: $result2');

  // 12. ITERABLES AND LAZY EVALUATION
  final genesisVerses = bible.allVerses.where((v) => v.book == BibleBookEnum.genesis);
  final versesWithGod = genesisVerses.where((v) => v.containsWord('God'));

  // 13. PATTERN MATCHING (Modern Dart)
  final verseResult = bible.getVerseByRefResult('Genesis 1:1');
  switch (verseResult) {
    case Success(value: final v):
      print('Success: ${v.shortReference}');
    case Failure(error: final e):
      print('Error: $e');
  }

  // 14. CONVENIENCE METHODS
  final firstVerse = verse as Verse;
  print('Reference: ${firstVerse.reference}');
  print('Contains "beginning": ${firstVerse.containsWord('beginning')}');
  print('Contains all ["God", "created"]: ${firstVerse.containsAll(['God', 'created'])}');

  print('🎉 Bible IO example completed successfully!');
}

/// Main function to run the example.
Future<void> main() async {
  await bibleExample();
}