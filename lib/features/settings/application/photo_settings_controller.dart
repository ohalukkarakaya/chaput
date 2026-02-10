import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../me/application/me_controller.dart';
import '../../user/application/profile_controller.dart';
import '../data/settings_api.dart';
import '../data/settings_api_provider.dart';

class PhotoSettingsState {
  final bool isLoading;
  final String? errorMessage;
  final String? busyAction; // "upload" | "delete" | null

  const PhotoSettingsState({
    this.isLoading = false,
    this.errorMessage,
    this.busyAction,
  });

  PhotoSettingsState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? busyAction,
  }) {
    return PhotoSettingsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      busyAction: busyAction,
    );
  }
}

final photoSettingsControllerProvider =
AutoDisposeNotifierProvider<PhotoSettingsController, PhotoSettingsState>(
  PhotoSettingsController.new,
);

class PhotoSettingsController extends AutoDisposeNotifier<PhotoSettingsState> {
  @override
  PhotoSettingsState build() => const PhotoSettingsState();

  SettingsApi get _api => ref.read(settingsApiProvider);

  String _mapError(Object e) {
    // DioException ise backend {ok:false,error:"..."} veya string gelebilir
    if (e is DioException) {
      final data = e.response?.data;
      final s = (data is Map) ? (data['error']?.toString() ?? '') : data?.toString() ?? '';

      if (s.contains('file_required')) return 'errors.file_required';
      if (s.contains('file_too_large')) return 'errors.file_too_large';
      if (s.contains('image_decode_failed')) return 'errors.image_decode_failed';
      if (s.contains('bad_multipart')) return 'errors.bad_multipart';
      if (s.contains('db_error')) return 'errors.db_error';
      if (s.contains('unauthorized')) return 'errors.unauthorized';

      return 'errors.http_status';
    }

    final s = e.toString();
    if (s.contains('user_not_found')) return 'errors.user_not_found';
    if (s.contains('unknown_error')) return 'errors.unknown_error';
    return 'errors.generic';
  }

  String? _loggedInUserId() {
    final meAsync = ref.read(meControllerProvider);

    // meControllerProvider AsyncValue ise:
    return meAsync.maybeWhen(
      data: (me) => me?.user?.userId,
      orElse: () => null,
    );
  }

  Future<bool> uploadPhotoFromPath(String path) async {
    state = state.copyWith(isLoading: true, busyAction: 'upload', errorMessage: null);
    try {
      final file = await MultipartFile.fromFile(path);
      await _api.uploadMePhoto(file: file);

      // ✅ refresh me (UI değil controller)
      await ref.read(meControllerProvider.notifier).fetchAndStoreMe();

      final meId = _loggedInUserId();
      if (meId != null && meId.isNotEmpty) {
        ref.invalidate(profileControllerProvider(meId));
      }

      state = state.copyWith(isLoading: false, busyAction: null, errorMessage: null);
      return true;
    } on DioException catch (e, st) {
      log('upload photo dio error', error: e, stackTrace: st);
      state = state.copyWith(isLoading: false, busyAction: null, errorMessage: _mapError(e));
      return false;
    } catch (e, st) {
      log('upload photo unknown error', error: e, stackTrace: st);
      state = state.copyWith(isLoading: false, busyAction: null, errorMessage: _mapError(e));
      return false;
    }
  }

  Future<bool> deletePhoto() async {
    state = state.copyWith(isLoading: true, busyAction: 'delete', errorMessage: null);
    try {
      await _api.deleteMePhoto();
      await ref.read(meControllerProvider.notifier).fetchAndStoreMe();
      final meId = _loggedInUserId();
      if (meId != null && meId.isNotEmpty) {
        ref.invalidate(profileControllerProvider(meId));
      }
      state = state.copyWith(isLoading: false, busyAction: null, errorMessage: null);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, busyAction: null, errorMessage: _mapError(e));
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, busyAction: null, errorMessage: _mapError(e));
      return false;
    }
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: null);
    }
  }
}
