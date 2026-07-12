import 'package:bible_io/bible_io.dart';
import 'package:test/test.dart';

void main() {
  test('public entrypoint exposes Bible and references 1.1 APIs together', () {
    const reference = VerseRef(book: BibleBookEnum.john, chapter: 3, verse: 16);
    final bible = Bible.fromBooks([
      Book(BibleBookEnum.john, [
        Chapter(BibleBookEnum.john, 3, const [
          Verse(BibleBookEnum.john, 3, 16, 'For God so loved the world.'),
        ]),
      ]),
    ]);

    expect(reference.osisIdentifier, 'John.3.16');
    expect(bible.resolveReference(reference).single.text, contains('loved'));
  });
}
