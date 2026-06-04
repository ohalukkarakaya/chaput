import 'package:firebase_messaging/firebase_messaging.dart';

class FirebaseTokenCleanup {
  const FirebaseTokenCleanup._();

  static Future<void> deleteLocalMessagingToken() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
      // FCM token cleanup is best-effort; logout must not fail because of it.
    }
  }
}
