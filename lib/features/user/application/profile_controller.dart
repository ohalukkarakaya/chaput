import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../data/profile_api.dart';
import '../../../../core/network/dio_provider.dart';

class ProfileState {
  const ProfileState({
    required this.isLoading,
    this.error,
    this.errorCode,
    this.profileJson,
    this.treeId,
  });

  final bool isLoading;
  final String? error;
  final String? errorCode;
  final Map<String, dynamic>? profileJson;
  final String? treeId;

  bool get isUnavailableProfile {
    const unavailableCodes = {
      'user_not_found',
      'profile_not_found',
      'blocked',
      'forbidden',
      'bad_hex',
      'bad_hex_len',
    };
    return errorCode != null && unavailableCodes.contains(errorCode);
  }

  ProfileState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? errorCode,
    bool clearErrorCode = false,
    Map<String, dynamic>? profileJson,
    String? treeId,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      errorCode: clearErrorCode ? null : errorCode ?? this.errorCode,
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

String _profileErrorCode(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    final code = data is Map ? data['error']?.toString() : null;
    if (code != null && code.isNotEmpty) return code;
    final status = error.response?.statusCode;
    if (status == 401) return 'unauthorized';
    if (status == 403) return 'forbidden';
    if (status == 404) return 'user_not_found';
  }

  final text = error.toString();
  const knownCodes = [
    'user_not_found',
    'profile_not_found',
    'blocked',
    'forbidden',
    'bad_hex_len',
    'bad_hex',
  ];
  for (final code in knownCodes) {
    if (text.contains(code)) return code;
  }
  return 'profile_error';
}

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
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearErrorCode: true,
    );

    _fetchTree(userId);

    try {
      final profile = await _api.getProfile(userId);
      if (profile['ok'] != true) {
        throw Exception(profile['error'] ?? 'profile_error');
      }

      state = state.copyWith(
        isLoading: false,
        clearError: true,
        clearErrorCode: true,
        profileJson: profile,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        errorCode: _profileErrorCode(e),
      );
      return;
    }
  }

  Future<void> _fetchTree(String userId) async {
    try {
      final tree = await _api.getTree(userId);
      if (tree['ok'] != true) {
        throw Exception(tree['error'] ?? 'tree_error');
      }

      state = state.copyWith(treeId: tree['tree_id']?.toString());
    } catch (e) {
      if (state.profileJson == null && state.errorCode == null) {
        state = state.copyWith(error: e.toString());
      }
    }
  }

  Future<void> refetch() => _fetch(arg);

  void updateGalleryPhotos(List<Map<String, dynamic>> photos) {
    final current = state.profileJson;
    if (current == null) return;
    final next = Map<String, dynamic>.from(current);
    next['profile_gallery_photos'] = photos
        .map((photo) => Map<String, dynamic>.from(photo))
        .toList(growable: false);
    state = state.copyWith(profileJson: next);
  }
}
