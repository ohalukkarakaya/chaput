import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/profile_preview.dart';

final profileVisitHistoryProvider =
    NotifierProvider<ProfileVisitHistoryController, List<ProfilePreview>>(
      ProfileVisitHistoryController.new,
    );

class ProfileVisitHistoryController extends Notifier<List<ProfilePreview>> {
  static const int _maxItems = 5;

  @override
  List<ProfilePreview> build() => const [];

  void record(ProfilePreview preview) {
    if (preview.id.isEmpty) return;

    final next = <ProfilePreview>[
      preview,
      ...state.where((item) => item.id != preview.id),
    ];

    state = next.take(_maxItems).toList(growable: false);
  }
}
