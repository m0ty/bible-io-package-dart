/// Search-index construction policy for a loaded Bible.
enum SearchIndexMode {
  /// Build the term index while the Bible is initialized.
  eager,

  /// Build the term index on the first indexed search.
  lazy,

  /// Never retain a term index; indexed modes fall back to scanning.
  disabled,
}

/// Strictness controls for decoded Bible content.
class BibleDataValidationOptions {
  final bool requireBooks;
  final bool requireChapters;
  final bool requireVerses;
  final bool requireVerseText;

  const BibleDataValidationOptions({
    this.requireBooks = true,
    this.requireChapters = true,
    this.requireVerses = true,
    this.requireVerseText = true,
  });

  /// Compatibility policy for intentionally incomplete or skeletal data.
  static const permissive = BibleDataValidationOptions(
    requireBooks: false,
    requireChapters: false,
    requireVerses: false,
    requireVerseText: false,
  );

  BibleDataValidationOptions copyWith({
    bool? requireBooks,
    bool? requireChapters,
    bool? requireVerses,
    bool? requireVerseText,
  }) {
    return BibleDataValidationOptions(
      requireBooks: requireBooks ?? this.requireBooks,
      requireChapters: requireChapters ?? this.requireChapters,
      requireVerses: requireVerses ?? this.requireVerses,
      requireVerseText: requireVerseText ?? this.requireVerseText,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BibleDataValidationOptions &&
          requireBooks == other.requireBooks &&
          requireChapters == other.requireChapters &&
          requireVerses == other.requireVerses &&
          requireVerseText == other.requireVerseText;

  @override
  int get hashCode => Object.hash(
        requireBooks,
        requireChapters,
        requireVerses,
        requireVerseText,
      );
}

/// Options shared by synchronous and asynchronous Bible construction.
class BibleLoadOptions {
  final BibleDataValidationOptions validation;
  final SearchIndexMode searchIndexMode;
  final bool parseInBackground;

  const BibleLoadOptions({
    this.validation = const BibleDataValidationOptions(),
    this.searchIndexMode = SearchIndexMode.eager,
    this.parseInBackground = true,
  });

  BibleLoadOptions copyWith({
    BibleDataValidationOptions? validation,
    SearchIndexMode? searchIndexMode,
    bool? parseInBackground,
  }) {
    return BibleLoadOptions(
      validation: validation ?? this.validation,
      searchIndexMode: searchIndexMode ?? this.searchIndexMode,
      parseInBackground: parseInBackground ?? this.parseInBackground,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BibleLoadOptions &&
          validation == other.validation &&
          searchIndexMode == other.searchIndexMode &&
          parseInBackground == other.parseInBackground;

  @override
  int get hashCode =>
      Object.hash(validation, searchIndexMode, parseInBackground);
}

/// Stage reported while asynchronously loading Bible content.
enum BibleLoadPhase { reading, processing, complete }

/// Structured loading progress suitable for UI progress indicators.
class BibleLoadProgress {
  final BibleLoadPhase phase;
  final double fraction;
  final double phaseFraction;

  BibleLoadProgress({
    required this.phase,
    required double fraction,
    required double phaseFraction,
  })  : fraction = _validateFraction(fraction, 'fraction'),
        phaseFraction = _validateFraction(phaseFraction, 'phaseFraction');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BibleLoadProgress &&
          phase == other.phase &&
          fraction == other.fraction &&
          phaseFraction == other.phaseFraction;

  @override
  int get hashCode => Object.hash(phase, fraction, phaseFraction);

  @override
  String toString() => 'BibleLoadProgress(phase: $phase, fraction: $fraction, '
      'phaseFraction: $phaseFraction)';
}

double _validateFraction(double value, String name) {
  if (!value.isFinite || value < 0 || value > 1) {
    throw RangeError.range(value, 0, 1, name);
  }
  return value;
}

typedef BibleLoadProgressCallback = void Function(BibleLoadProgress progress);
