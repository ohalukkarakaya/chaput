import '../../../../chaput/domain/chaput_thread.dart';

/// Keep existing threads in their session order. Insert new personal chaputs
/// first, and other new chaputs next to their API-ranked successor.
List<ChaputThreadItem> orderChaputSession({
  required List<String> previousIds,
  required List<ChaputThreadItem> source,
  required String viewerId,
  String? createdThreadId,
}) {
  final byId = {for (final t in source) t.threadId: t};
  final ids = previousIds.where(byId.containsKey).toList();
  final existing = ids.toSet();
  final personal = <String>[];
  for (var i = 0; i < source.length; i++) {
    final t = source[i];
    if (existing.contains(t.threadId)) continue;
    if (t.threadId == createdThreadId ||
        t.userAId.toLowerCase() == viewerId.toLowerCase() ||
        t.userBId.toLowerCase() == viewerId.toLowerCase()) {
      personal.add(t.threadId);
    } else {
      var position = ids.length;
      for (var j = i + 1; j < source.length; j++) {
        final next = ids.indexOf(source[j].threadId);
        if (next >= 0) {
          position = next;
          break;
        }
      }
      ids.insert(position, t.threadId);
    }
    existing.add(t.threadId);
  }
  return [...personal, ...ids].map((id) => byId[id]!).toList(growable: false);
}
