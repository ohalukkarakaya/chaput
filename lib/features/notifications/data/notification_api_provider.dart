import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import 'notification_api.dart';

final notificationApiProvider = Provider<NotificationApi>((ref) {
  final dio = ref.read(dioProvider);
  return NotificationApi(dio);
});
