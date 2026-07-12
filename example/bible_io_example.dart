import 'package:bible_io/bible_io.dart';

void main() {
  final bible = Bible.fromDecodedJson({
    'language': 'English',
    'metadata': {
      'translationName': 'Example Translation',
      'abbreviation': 'EX',
    },
    'books': {
      'jo': {
        'name': 'John',
        'chapters': {
          '3': {
            '16': 'For God so loved the world...',
            '18': 'Whoever believes is not condemned...',
          },
        },
      },
    },
  });

  final verse = bible.getVerseByRef('John 3:16');
  print('${verse.reference} — ${verse.text}');

  final passage = bible.getPassage('John 3:16,18');
  print('Selected ${passage.length} verses from ${bible.abbreviation}.');

  final search = bible.searchAdvanced(text: 'believes');
  for (final hit in search.hits) {
    print('${hit.reference}: ${hit.snippet}');
  }
}
