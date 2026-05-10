import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../me/application/me_controller.dart';
import '../../user/application/profile_controller.dart';
import 'photo_upload_preparer.dart';
import '../data/settings_api.dart';
import '../data/settings_api_provider.dart';

class PhotoSettingsError {
  const PhotoSettingsError(this.key, {this.params});

  final String key;
  final Map<String, String>? params;
}

class PhotoSettingsState {
  const PhotoSettingsState({
    this.isLoading = false,
    this.error,
    this.busyAction,
  });

  final bool isLoading;
  final PhotoSettingsError? error;
  final String? busyAction;

  PhotoSettingsState copyWith({
    bool? isLoading,
    PhotoSettingsError? error,
    bool clearError = false,
    Object? busyAction = _busyActionSentinel,
  }) {
    return PhotoSettingsState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      busyAction: identical(busyAction, _busyActionSentinel)
          ? this.busyAction
          : busyAction as String?,
    );
  }
}

const _busyActionSentinel = Object();

final photoSettingsControllerProvider =
    AutoDisposeNotifierProvider<PhotoSettingsController, PhotoSettingsState>(
      PhotoSettingsController.new,
    );

class PhotoSettingsController extends AutoDisposeNotifier<PhotoSettingsState> {
  @override
  PhotoSettingsState build() => const PhotoSettingsState();

  SettingsApi get _api => ref.read(settingsApiProvider);

  PhotoSettingsError _mapError(Object e) {
    if (e is DioException) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 413) {
        return const PhotoSettingsError('errors.file_too_large');
      }

      final data = e.response?.data;
      final s = (data is Map)
          ? (data['error']?.toString() ?? '')
          : data?.toString() ?? '';

      if (s.contains('file_required')) {
        return const PhotoSettingsError('errors.file_required');
      }
      if (s.contains('file_too_large')) {
        return const PhotoSettingsError('errors.file_too_large');
      }
      if (s.contains('image_decode_failed') ||
          s.contains('image_encode_failed')) {
        return const PhotoSettingsError('errors.image_decode_failed');
      }
      if (s.contains('bad_multipart')) {
        return const PhotoSettingsError('errors.bad_multipart');
      }
      if (s.contains('db_error')) {
        return const PhotoSettingsError('errors.db_error');
      }
      if (s.contains('unauthorized')) {
        return const PhotoSettingsError('errors.unauthorized');
      }
      if (statusCode != null) {
        return PhotoSettingsError(
          'errors.http_status',
          params: {'status': statusCode.toString()},
        );
      }
      return const PhotoSettingsError('errors.generic');
    }

    final s = e.toString();
    if (s.contains('file_required')) {
      return const PhotoSettingsError('errors.file_required');
    }
    if (s.contains('file_too_large')) {
      return const PhotoSettingsError('errors.file_too_large');
    }
    if (s.contains('image_decode_failed') ||
        s.contains('image_encode_failed')) {
      return const PhotoSettingsError('errors.image_decode_failed');
    }
    if (s.contains('user_not_found')) {
      return const PhotoSettingsError('errors.user_not_found');
    }
    if (s.contains('unknown_error')) {
      return const PhotoSettingsError('errors.unknown_error');
    }
    return const PhotoSettingsError('errors.generic');
  }

  String? _loggedInUserId() {
    final meAsync = ref.read(meControllerProvider);
    return meAsync.maybeWhen(data: (me) => me?.user.userId, orElse: () => null);
  }

  Future<bool> uploadPhotoFromPath(String path) async {
    state = state.copyWith(
      isLoading: true,
      busyAction: 'upload',
      clearError: true,
    );

    try {
      final prepared = await prepareProfilePhotoUpload(path);
      final file = MultipartFile.fromBytes(
        prepared.bytes,
        filename: prepared.filename,
      );
      await _api.uploadMePhoto(file: file);

      await ref.read(meControllerProvider.notifier).fetchAndStoreMe();

      final meId = _loggedInUserId();
      if (meId != null && meId.isNotEmpty) {
        ref.invalidate(profileControllerProvider(meId));
      }

      state = state.copyWith(
        isLoading: false,
        busyAction: null,
        clearError: true,
      );
      return true;
    } on DioException catch (e, st) {
      log('upload photo dio error', error: e, stackTrace: st);
      state = state.copyWith(
        isLoading: false,
        busyAction: null,
        error: _mapError(e),
      );
      return false;
    } catch (e, st) {
      log('upload photo unknown error', error: e, stackTrace: st);
      state = state.copyWith(
        isLoading: false,
        busyAction: null,
        error: _mapError(e),
      );
      return false;
    }
  }

  Future<bool> deletePhoto() async {
    state = state.copyWith(
      isLoading: true,
      busyAction: 'delete',
      clearError: true,
    );
    try {
      await _api.deleteMePhoto();
      await ref.read(meControllerProvider.notifier).fetchAndStoreMe();
      final meId = _loggedInUserId();
      if (meId != null && meId.isNotEmpty) {
        ref.invalidate(profileControllerProvider(meId));
      }
      state = state.copyWith(
        isLoading: false,
        busyAction: null,
        clearError: true,
      );
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        busyAction: null,
        error: _mapError(e),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        busyAction: null,
        error: _mapError(e),
      );
      return false;
    }
  }

  void clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }
}
