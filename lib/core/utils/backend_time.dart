DateTime? parseBackendUtcDateTime(dynamic value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty || raw == 'null') return null;

  final hasZone = RegExp(r'(?:Z|[+-]\d{2}:\d{2})$').hasMatch(raw);
  final normalized = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
  final source = hasZone ? normalized : '${normalized}Z';

  final parsed = DateTime.tryParse(source);
  if (parsed == null) return null;
  return parsed.isUtc ? parsed : parsed.toUtc();
}
