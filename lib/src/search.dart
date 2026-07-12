import 'package:bible_io_references/bible_io_references.dart';

import 'book.dart';
import 'verse.dart';

/// Search mode for advanced text queries.
enum SearchMode {
  /// Match any of the tokenized terms.
  any,

  /// Match all of the tokenized terms.
  all,

  /// Match the exact phrase.
  exact,
}

/// Options controlling advanced Bible search behavior.
class SearchOptions {
  final SearchMode mode;
  final bool caseSensitive;
  final bool wholeWords;
  final int? maxResults;
  final BibleBookEnum? book;
  final int? chapter;
  final int? verse;

  const SearchOptions({
    this.mode = SearchMode.exact,
    this.caseSensitive = false,
    this.wholeWords = false,
    this.maxResults,
    this.book,
    this.chapter,
    this.verse,
  });
}

/// UTF-16 code-unit range for a search match within a verse.
class TextRange {
  final int start;
  final int end;

  const TextRange({required this.start, required this.end})
    : assert(start >= 0),
      assert(end >= start);

  int get length => end - start;

  bool contains(int offset) => offset >= start && offset < end;

  @override
  String toString() => 'TextRange($start, $end)';

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TextRange && other.start == start && other.end == end;
  }

  @override
  int get hashCode => Object.hash(start, end);
}

/// Display-ready metadata for one matched verse.
class SearchHit {
  final Verse verse;
  final Book book;
  final String reference;
  final List<TextRange> matchRanges;
  final String snippet;

  SearchHit({
    required this.verse,
    required this.book,
    String? reference,
    List<TextRange> matchRanges = const [],
    String? snippet,
  }) : reference =
           reference ??
           '${book.name} ${verse.chapterNumber}:${verse.verseNumber}',
       matchRanges = List.unmodifiable(matchRanges),
       snippet = snippet ?? verse.text {
    if (book.bookEnum != verse.book) {
      throw ArgumentError.value(
        book,
        'book',
        'SearchHit book must contain the matched verse.',
      );
    }
  }
}

/// Search results with matched verses and display metadata.
class SearchResults {
  final String query;
  final List<Verse> verses;
  final List<SearchHit> hits;

  /// Compatibility constructor for callers that only have verses.
  ///
  /// Prefer [SearchResults.fromHits] when match metadata is available.
  SearchResults(this.query, List<Verse> verses, {List<SearchHit>? hits})
    : verses = List.unmodifiable(verses),
      hits = List.unmodifiable(hits ?? const []) {
    if (hits != null &&
        (hits.length != verses.length ||
            !_sameVerses(verses, hits.map((hit) => hit.verse)))) {
      throw ArgumentError.value(
        hits,
        'hits',
        'Search result hits must correspond to verses in the same order.',
      );
    }
  }

  SearchResults.fromHits(this.query, List<SearchHit> hits)
    : hits = List.unmodifiable(hits),
      verses = List.unmodifiable(hits.map((hit) => hit.verse));

  int get count => verses.length;

  bool get isEmpty => verses.isEmpty;
  bool get isNotEmpty => verses.isNotEmpty;

  /// Group results by book.
  Map<BibleBookEnum, List<Verse>> get byBook {
    final grouped = <BibleBookEnum, List<Verse>>{};
    for (final verse in verses) {
      grouped.putIfAbsent(verse.book, () => []).add(verse);
    }
    return Map.unmodifiable({
      for (final entry in grouped.entries)
        entry.key: List<Verse>.unmodifiable(entry.value),
    });
  }

  /// Group results by chapter.
  Map<String, List<Verse>> get byChapter {
    final grouped = <String, List<Verse>>{};
    for (final verse in verses) {
      final key = '${verse.book.fullName} ${verse.chapterNumber}';
      grouped.putIfAbsent(key, () => []).add(verse);
    }
    return Map.unmodifiable({
      for (final entry in grouped.entries)
        entry.key: List<Verse>.unmodifiable(entry.value),
    });
  }

  @override
  String toString() => 'SearchResults(query: "$query", count: $count)';

  static bool _sameVerses(Iterable<Verse> first, Iterable<Verse> second) {
    final firstIterator = first.iterator;
    final secondIterator = second.iterator;
    while (firstIterator.moveNext()) {
      if (!secondIterator.moveNext() ||
          !identical(firstIterator.current, secondIterator.current)) {
        return false;
      }
    }
    return !secondIterator.moveNext();
  }
}
