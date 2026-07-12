import 'dart:async';
import 'dart:isolate';

/// Run CPU-heavy Bible parsing outside the caller isolate on native targets.
Future<T> runBibleTask<T>(FutureOr<T> Function() computation) {
  return Isolate.run(computation);
}
