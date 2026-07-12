import 'package:bible_io_references/bible_io_references.dart';

/// Base exception for all Bible-related errors.
class BibleError implements Exception {
  final String message;
  final StackTrace? stackTrace;
  final dynamic context;
  final Object? cause;

  BibleError(this.message, {this.stackTrace, this.context, this.cause});

  @override
  String toString() {
    final buffer = StringBuffer('BibleError: $message');
    if (context != null) {
      buffer.write('\nContext: $context');
    }
    if (cause != null) {
      buffer.write('\nCause: $cause');
    }
    if (stackTrace != null) {
      buffer.write('\n$stackTrace');
    }
    return buffer.toString();
  }
}

/// Stable machine-readable codes used by [BibleDataFormatError].
///
/// Applications can safely branch on these values without parsing a localized
/// or otherwise human-facing error message.
abstract final class BibleDataFormatErrorCode {
  static const invalidJson = 'invalid_json';
  static const invalidType = 'invalid_type';
  static const missingField = 'missing_field';
  static const invalidValue = 'invalid_value';
  static const duplicateId = 'duplicate_id';
  static const reservedField = 'reserved_field';
  static const nonJsonValue = 'non_json_value';
}

/// Raised when serialized Bible or catalog data violates its data contract.
///
/// [path] uses JSONPath-like notation (for example `$.books.gn.chapters`) so
/// callers can point users and content tooling at the exact failing value.
/// [code] is stable and machine-readable, while [message] is intended for
/// people. [value] and [cause] preserve diagnostic context without requiring
/// loaders to expose implementation-specific `TypeError`s or `FormatException`s.
class BibleDataFormatError extends BibleError {
  final String code;
  final String path;
  final Object? value;

  BibleDataFormatError({
    required this.code,
    required this.path,
    required String message,
    this.value,
    Object? cause,
    StackTrace? stackTrace,
  }) : super(
          message,
          stackTrace: stackTrace,
          context: {
            'code': code,
            'path': path,
            if (value != null) 'value': value,
          },
          cause: cause,
        );

  @override
  String toString() {
    final buffer = StringBuffer(
      'BibleDataFormatError($code) at $path: $message',
    );
    if (value != null) {
      buffer.write('\nValue: $value');
    }
    if (cause != null) {
      buffer.write('\nCause: $cause');
    }
    if (stackTrace != null) {
      buffer.write('\n$stackTrace');
    }
    return buffer.toString();
  }
}

/// Raised when the requested book is out of range.
class BookNotFoundError extends BibleError {
  BookNotFoundError(dynamic book, {StackTrace? stackTrace})
      : super(
          'Book ${_formatBook(book)} is out of range.',
          stackTrace: stackTrace,
          context: book,
        );
}

/// Raised when the requested chapter number is out of range.
class ChapterNotFoundError extends BibleError {
  ChapterNotFoundError(
    dynamic book,
    int chapterNumber, {
    StackTrace? stackTrace,
  }) : super(
          'Chapter $chapterNumber in book ${_formatBook(book)} is out of range.',
          stackTrace: stackTrace,
          context: {'book': book, 'chapter': chapterNumber},
        );
}

/// Raised when the requested verse number is out of range.
class VerseNotFoundError extends BibleError {
  VerseNotFoundError(
    dynamic book,
    int chapterNumber,
    int verseNumber, {
    StackTrace? stackTrace,
  }) : super(
          'Verse $verseNumber in ${_formatBook(book)} $chapterNumber is out of range.',
          stackTrace: stackTrace,
          context: {
            'book': book,
            'chapter': chapterNumber,
            'verse': verseNumber,
          },
        );
}

/// Raised when a reference string cannot be parsed.
class ReferenceParseError extends BibleError {
  ReferenceParseError(
    String reference, {
    StackTrace? stackTrace,
    dynamic context,
  }) : super(
          'Cannot parse reference: "$reference"',
          stackTrace: stackTrace,
          context: context,
        );
}

String _formatBook(dynamic book) {
  if (book is BibleBookEnum) {
    return book.fullName;
  }
  return book.toString();
}
