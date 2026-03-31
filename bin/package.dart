import 'package:bible_io/bible_io.dart';

void main(List<String> arguments) async {
  if (arguments.isEmpty) {
    print('Usage: dart run bin/package.dart <path_to_bible_json>');
    return;
  }

  final path = arguments[0];
  try {
    final bible = await Bible.load(path);

    print('Loaded Bible with ${bible.books.length} books');
    print('Language: ${bible.language}');

    // Example: Get Genesis 1:1
    final genesis = bible.getBook(BibleBookEnum.genesis);
    print('Genesis has ${genesis.chapters.length} chapters');

    final verse = bible.getVerse(BibleBookEnum.genesis, 1, 1);
    print('Genesis 1:1: ${verse.text}');

    // Search for "God"
    final results = bible.search('God');
    print('Found ${results.length} verses containing "God"');

    // Get by ref
    final john316 = bible.getByRef('John 3:16');
    if (john316 is Verse) {
      print('John 3:16: ${john316.text}');
    }

    // Get range
    final range = bible.getByRef('Genesis 1:1-3');
    if (range is List<Verse>) {
      print('Genesis 1:1-3: ${range.length} verses');
    }
  } catch (e) {
    print('Error: $e');
  }
}
