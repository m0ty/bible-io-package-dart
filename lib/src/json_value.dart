/// Deeply freezes a JSON-compatible object map.
Map<String, Object?> freezeJsonMap(
  Map<String, Object?> values, {
  Set<String> reservedKeys = const {},
  String parameterName = 'values',
}) {
  for (final key in reservedKeys) {
    if (values.containsKey(key)) {
      throw ArgumentError.value(
        values,
        parameterName,
        'must not contain the structural key "$key"',
      );
    }
  }
  if (values.isEmpty) return const {};
  return Map<String, Object?>.unmodifiable({
    for (final entry in values.entries)
      entry.key: freezeJsonValue(
        entry.value,
        path: '$parameterName.${entry.key}',
      ),
  });
}

/// Deeply freezes one JSON-compatible value.
Object? freezeJsonValue(Object? value, {String path = r'$'}) {
  if (value == null || value is String || value is bool || value is int) {
    return value;
  }
  if (value is double) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, path, 'must be a finite JSON number');
    }
    return value;
  }
  if (value is List) {
    return List<Object?>.unmodifiable([
      for (var index = 0; index < value.length; index++)
        freezeJsonValue(value[index], path: '$path[$index]'),
    ]);
  }
  if (value is Map) {
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw ArgumentError.value(
          key,
          path,
          'JSON object keys must be strings',
        );
      }
      result[key] = freezeJsonValue(entry.value, path: '$path.$key');
    }
    return Map<String, Object?>.unmodifiable(result);
  }
  throw ArgumentError.value(value, path, 'must be JSON-compatible');
}

bool jsonValueEquals(Object? first, Object? second) {
  if (identical(first, second)) return true;
  if (first is List && second is List) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (!jsonValueEquals(first[index], second[index])) return false;
    }
    return true;
  }
  if (first is Map && second is Map) {
    if (first.length != second.length) return false;
    for (final entry in first.entries) {
      if (!second.containsKey(entry.key) ||
          !jsonValueEquals(entry.value, second[entry.key])) {
        return false;
      }
    }
    return true;
  }
  return first == second;
}

int jsonValueHash(Object? value) {
  if (value is List) return Object.hashAll(value.map(jsonValueHash));
  if (value is Map) {
    return Object.hashAllUnordered(
      value.entries.map(
        (entry) => Object.hash(entry.key, jsonValueHash(entry.value)),
      ),
    );
  }
  return value.hashCode;
}
