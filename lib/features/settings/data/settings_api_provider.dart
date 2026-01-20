import 'package:chaput/features/settings/data/settings_api.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chaput/core/network/dio_provider.dart';

import 'email_change_api.dart';

final settingsApiProvider = Provider<SettingsApi>((ref) {
  return SettingsApi(ref.read(dioProvider));
});

final emailChangeApiProvider = Provider<EmailChangeApi>((ref) {
  return EmailChangeApi(ref.read(dioProvider));
});
