import 'package:bible_io_references/package.dart';

/// Base exception for all Bible-related errors.
class BibleError implements Exception {
  final String message;
  final StackTrace? stackTrace;
  final dynamic context;

  BibleError(this.message, {this.stackTrace, this.context});

  @override
  String toString() {
    final buffer = StringBuffer('BibleError: $message');
    if (context != null) {
      buffer.write('\nContext: $context');
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
      : super('Book ${_formatBook(book)} is out of range.', stackTrace: stackTrace, context: book);
}

/// Raised when the requested chapter number is out of range.
class ChapterNotFoundError extends BibleError {
  ChapterNotFoundError(dynamic book, int chapterNumber, {StackTrace? stackTrace})
      : super('Chapter $chapterNumber in book ${_formatBook(book)} is out of range.',
            stackTrace: stackTrace, context: {'book': book, 'chapter': chapterNumber});
}

/// Raised when the requested verse number is out of range.
class VerseNotFoundError extends BibleError {
  VerseNotFoundError(dynamic book, int chapterNumber, int verseNumber, {StackTrace? stackTrace})
      : super('Verse $verseNumber in ${_formatBook(book)} $chapterNumber is out of range.',
            stackTrace: stackTrace, context: {'book': book, 'chapter': chapterNumber, 'verse': verseNumber});
}

/// Raised when a reference string cannot be parsed.
class ReferenceParseError extends BibleError {
  ReferenceParseError(String reference, {StackTrace? stackTrace, dynamic context})
      : super('Cannot parse reference: "$reference"', stackTrace: stackTrace, context: context);
}

String _formatBook(dynamic book) {
  if (book is BibleBookEnum) {
    return book.fullName;
  }
  return book.toString();
}