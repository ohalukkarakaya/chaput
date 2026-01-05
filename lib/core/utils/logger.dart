import 'dart:developer' as dev;

class Log {
  static void d(Object? msg, {String tag = 'Chaput'}) {
    dev.log('$msg', name: tag);
  }

  static void e(Object? msg, {String tag = 'Chaput', Object? error, StackTrace? st}) {
    dev.log('$msg', name: tag, error: error, stackTrace: st);
  }
}