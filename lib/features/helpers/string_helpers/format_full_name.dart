String formatFullName(String fullName) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();

  if (parts.isEmpty) return '';

  if (parts.length == 1) {
    return parts.first.toUpperCase();
  }

  return parts.asMap().entries.map((entry) {
    final index = entry.key;
    final word = entry.value;

    if (index == parts.length - 1) {
      return word.toUpperCase();
    }

    final lower = word.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }).join(' ');
}