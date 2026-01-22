import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/privacy_api_provider.dart';

class PrivacyState {
  const PrivacyState({
    required this.isLoading,
    this.error,
    this.isPublic,
  });

  final bool isLoading;
  final String? error;

  /// backend truth (null = henüz yüklenmedi)
  final bool? isPublic;

  PrivacyState copyWith({
    bool? isLoading,
    String? error,
    bool? isPublic,
  }) {
    return PrivacyState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isPublic: isPublic ?? this.isPublic,
    );
  }

  static const empty = PrivacyState(isLoading: false);
}

final privacyControllerProvider =
AutoDisposeNotifierProvider<PrivacyController, PrivacyState>(
  PrivacyController.new,
);

class PrivacyController extends AutoDisposeNotifier<PrivacyState> {
  @override
  PrivacyState build() {
    // ekran açılınca çek
    Future.microtask(_load);
    return PrivacyState.empty.copyWith(isLoading: true);
  }

  Future<void> _load() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final api = ref.read(privacyApiProvider);
      final isPublic = await api.getIsPublic();
      state = state.copyWith(isLoading: false, isPublic: isPublic);
    } catch (e, st) {
      log('privacy load error: $e', stackTrace: st);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> setPrivate(bool privateOn) async {
    final prev = state;

    // privateOn=true => is_public=false
    final desiredIsPublic = !privateOn;

    // optimistic
    state = state.copyWith(isPublic: desiredIsPublic, error: null);

    try {
      final api = ref.read(privacyApiProvider);
      final savedIsPublic = await api.setIsPublic(desiredIsPublic);
      state = state.copyWith(isPublic: savedIsPublic);
    } catch (e) {
      // rollback
      state = prev.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> refetch() => _load();
}