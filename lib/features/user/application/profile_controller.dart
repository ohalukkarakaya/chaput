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

final profileControllerProvider =
AutoDisposeNotifierProviderFamily<ProfileController, ProfileState, String>(
  ProfileController.new,
);

class ProfileController extends AutoDisposeFamilyNotifier<ProfileState, String> {
  ProfileApi get _api => ref.read(profileApiProvider);

  @override
  ProfileState build(String userId) {
    // önce state'i initialize et
    final initial = ProfileState.empty.copyWith(isLoading: true);

    // sonra fetch'i bir sonraki tick'te başlat
    Future.microtask(() => _fetch(userId));

    return initial;
  }

  Future<void> _fetch(String userId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final results = await Future.wait([
        _api.getProfile(userId),
        _api.getTree(userId),
      ]);

      final profile = results[0] as Map<String, dynamic>;
      final tree = results[1] as Map<String, dynamic>;

      if (profile['ok'] != true) {
        throw Exception(profile['error'] ?? 'profile_error');
      }
      if (tree['ok'] != true) {
        throw Exception(tree['error'] ?? 'tree_error');
      }

      state = state.copyWith(
        isLoading: false,
        profileJson: profile,
        treeId: tree['tree_id']?.toString(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refetch() => _fetch(arg);
}