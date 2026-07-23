import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../data/profile_api.dart';
import '../../../../core/network/dio_provider.dart';

class ProfileState {
  const ProfileState({
    required this.isLoading,
    this.error,
    this.profileJson,
    this.treeId,
  });

  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? profileJson;
  final String? treeId;

  ProfileState copyWith({
    bool? isLoading,
    String? error,
    Map<String, dynamic>? profileJson,
    String? treeId,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      profileJson: profileJson ?? this.profileJson,
      treeId: treeId ?? this.treeId,
    );
  }

  static const empty = ProfileState(isLoading: false);
}

/// API'yi provider üzerinden ver (late final patlamasın)
final profileApiProvider = Provider<ProfileApi>((ref) {
  final Dio dio = ref.read(dioProvider);
  return ProfileApi(dio);
});

final profileControllerProvider = NotifierProvider.autoDispose
    .family<ProfileController, ProfileState, String>(ProfileController.new);

class ProfileController extends Notifier<ProfileState> {
  ProfileController(this.arg);

  final String arg;

  ProfileApi get _api => ref.read(profileApiProvider);

  @override
  ProfileState build() {
    // önce state'i initialize et
    final initial = ProfileState.empty.copyWith(isLoading: true);

    // sonra fetch'i bir sonraki tick'te başlat
    Future.microtask(() => _fetch(arg));

    return initial;
  }

  Future<void> _fetch(String userId) async {
    state = state.copyWith(isLoading: true, error: null);

    _fetchTree(userId);

    try {
      final profile = await _api.getProfile(userId);
      if (profile['ok'] != true) {
        throw Exception(profile['error'] ?? 'profile_error');
      }

      state = state.copyWith(
        isLoading: false,
        error: null,
        profileJson: profile,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return;
    }
  }

  Future<void> _fetchTree(String userId) async {
    try {
      final tree = await _api.getTree(userId);
      if (tree['ok'] != true) {
        throw Exception(tree['error'] ?? 'tree_error');
      }

      state = state.copyWith(treeId: tree['tree_id']?.toString(), error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> refetch() => _fetch(arg);
}
