final _hexId = RegExp(r'^[0-9a-fA-F]{32}$');

/// REST uses SQL HEX() (uppercase); socket routes may use lowercase IDs.
String canonicalHexId(String value) =>
    _hexId.hasMatch(value) ? value.toUpperCase() : value;

Map<String, dynamic> canonicalSocketIds(Map<String, dynamic> data) => data.map((
  key,
  value,
) {
  if (value is Map<String, dynamic>) {
    return MapEntry(key, canonicalSocketIds(value));
  }
  if (value is List) {
    return MapEntry(
      key,
      value
          .map(
            (item) =>
                item is Map<String, dynamic> ? canonicalSocketIds(item) : item,
          )
          .toList(growable: false),
    );
  }
  if ((key == 'id' || key.endsWith('_id')) && value is String) {
    return MapEntry(key, canonicalHexId(value));
  }
  return MapEntry(key, value);
});
