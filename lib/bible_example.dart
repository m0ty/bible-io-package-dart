@Deprecated(
  'Example code is now under example/bible_io_example.dart and will be '
  'removed from lib in the next major release.',
)
library;

import 'package:bible_io/bible_io.dart';

/// Small compatibility example retained for callers of the former library.
///
/// New package examples belong under `example/`; see
/// `example/bible_io_example.dart` for the maintained entry point.
Future<void> bibleExample() {
  final bible = Bible.fromDecodedJson({
    'schemaVersion': 1,
    'language': 'English',
    'metadata': {
      'id': 'eng-example-1',
      'translationName': 'Example Translation',
      'abbreviation': 'EXT',
      'languageCode': 'en',
    },
    'bookOrder': ['jo'],
    'books': {
      'jo': {
        'name': 'John',
        'chapters': {
          '3': {'16': 'For God so loved the world...'},
        },
      },
    },
  });

  final verse = bible.getVerseByRef('John 3:16');
  print('${verse.reference} - ${verse.text}');
  return Future<void>.value();
}

Future<void> main() => bibleExample();
