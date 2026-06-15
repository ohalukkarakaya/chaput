class ChaputShareLinks {
  const ChaputShareLinks._();

  static const String origin = 'https://chaput.app';

  static String profile(String username) {
    final clean = username.trim();
    return '$origin/me/${Uri.encodeComponent(clean)}';
  }

  static String thread(String username, String threadId) {
    final cleanThreadId = threadId.trim();
    return '${profile(username)}/${Uri.encodeComponent(cleanThreadId)}';
  }

  static String message(String username, String threadId, String messageId) {
    final cleanMessageId = messageId.trim();
    return '${thread(username, threadId)}/${Uri.encodeComponent(cleanMessageId)}';
  }
}
