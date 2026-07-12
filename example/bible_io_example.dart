import 'package:bible_io/bible_io.dart';

void main() {
  final bible = Bible.fromDecodedJson({
    'schemaVersion': 1,
    'language': 'English',
    'metadata': {
      'id': 'eng-example-1',
      'translationName': 'Example Translation',
      'abbreviation': 'EX',
      'languageCode': 'en',
    },
    'bookOrder': ['jo'],
    'books': {
      'jo': {
        'name': 'John',
        'chapters': {
          '3': {
            '16': {
              'text': 'For God so loved the world...',
              'paragraphStart': true,
            },
            '18': 'Whoever believes is not condemned...',
          },
        },
      },
    },
  });

  final verse = bible.getVerseByRef('John 3:16');
  print('${verse.reference} - ${verse.text}');

  final persistedKey = BibleVerseKey.fromVerse(
    bible.metadata.id!,
    verse,
  ).toJson();
  print('Stable UI key: $persistedKey');

  final passage = bible.getPassage('John 3:16,18');
  print('Selected ${passage.length} verses from ${bible.abbreviation}.');

  final search = bible.searchWithOptions(
    'believes',
    SearchOptions(mode: SearchMode.exact, maxResults: 10),
  );
  for (final hit in search.hits) {
    print('${hit.reference}: ${hit.snippet}');
  }
}
