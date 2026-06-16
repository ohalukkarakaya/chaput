class ChaputShareLinks {
  const ChaputShareLinks._();

  static const String origin = 'https://chaput.app';

  static String profile(String username) {
    final clean = username.trim();
    return '$origin/me/${Uri.encodeComponent(clean)}';
  }

  static String thread(String username, String threadSegment) {
    final cleanThreadSegment = threadSegment.trim();
    return '${profile(username)}/${Uri.encodeComponent(cleanThreadSegment)}';
  }

  static String message(
    String username,
    String threadSegment,
    String messageId,
  ) {
    final cleanMessageId = messageId.trim();
    return '${thread(username, threadSegment)}/${Uri.encodeComponent(cleanMessageId)}';
  }
}
