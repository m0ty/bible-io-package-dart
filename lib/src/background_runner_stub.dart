import 'dart:async';

/// Web fallback for targets that do not provide native Dart isolates.
Future<T> runBibleTask<T>(FutureOr<T> Function() computation) async {
  return computation();
}
