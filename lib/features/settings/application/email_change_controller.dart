import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../me/application/me_controller.dart';
import '../data/email_change_api.dart';
import '../data/settings_api_provider.dart';

class EmailChangeState {
  final bool isLoading;
  final String? errorMessage;
  final bool codeRequested;
  final String newEmail;

  const EmailChangeState({
    this.isLoading = false,
    this.errorMessage,
    this.codeRequested = false,
    this.newEmail = '',
  });

  EmailChangeState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? codeRequested,
    String? newEmail,
  }) {
    return EmailChangeState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      codeRequested: codeRequested ?? this.codeRequested,
      newEmail: newEmail ?? this.newEmail,
    );
  }
}

final emailChangeControllerProvider =
AutoDisposeNotifierProvider<EmailChangeController, EmailChangeState>(
  EmailChangeController.new,
);

class EmailChangeController extends AutoDisposeNotifier<EmailChangeState> {
  @override
  EmailChangeState build() => const EmailChangeState();

  EmailChangeApi get _api => ref.read(emailChangeApiProvider);

  String _mapDioToMessage(DioException e) {
    final data = e.response?.data;
    final s = (data is Map) ? (data['error']?.toString() ?? '') : (data?.toString() ?? '');

    if (s.contains('missing_new_email')) return 'errors.missing_new_email';
    if (s.contains('missing_fields')) return 'errors.missing_fields';
    if (s.contains('invalid_email')) return 'errors.invalid_email';
    if (s.contains('email_taken')) return 'errors.email_taken';
    if (s.contains('rate_limited')) return 'errors.rate_limited';
    if (s.contains('code_not_found')) return 'errors.code_not_found';
    if (s.contains('code_expired')) return 'errors.code_expired';
    if (s.contains('invalid_code')) return 'errors.invalid_code';
    if (s.contains('too_many_attempts')) return 'errors.too_many_attempts';
    if (s.contains('db_error')) return 'errors.db_error';
    if (s.contains('unauthorized')) return 'errors.unauthorized';

    return 'errors.generic';
  }

  Future<bool> requestCode(String email) async {
    state = state.copyWith(isLoading: true, errorMessage: null, newEmail: email);

    try {
      await _api.requestChange(newEmail: email);
      state = state.copyWith(isLoading: false, codeRequested: true, errorMessage: null);
      return true;
    } on DioException catch (e, st) {
      log('request email change dio error', error: e, stackTrace: st);
      state = state.copyWith(isLoading: false, errorMessage: _mapDioToMessage(e));
      return false;
    } catch (e, st) {
      log('request email change unknown error', error: e, stackTrace: st);
      state = state.copyWith(isLoading: false, errorMessage: 'errors.generic');
      return false;
    }
  }

  Future<({bool ok, String? errorText, int? lockSeconds})> verifyCode(String code) async {
    final email = state.newEmail;
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _api.verifyChange(newEmail: email, code: code);

      // ✅ me refresh
      await ref.read(meControllerProvider.notifier).fetchAndStoreMe();

      state = state.copyWith(isLoading: false, errorMessage: null);
      return (ok: true, errorText: null, lockSeconds: null);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false);

      final status = e.response?.statusCode;
      final msg = _mapDioToMessage(e);

      // Email verify endpoint: too_many_attempts = 403
      if (status == 403 && (e.response?.data?.toString().contains('too_many_attempts') ?? false)) {
        return (ok: false, errorText: msg, lockSeconds: 60);
      }

      return (ok: false, errorText: msg, lockSeconds: null);
    } catch (_) {
      state = state.copyWith(isLoading: false, errorMessage: 'errors.generic');
      return (ok: false, errorText: 'errors.generic', lockSeconds: null);
    }
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: null);
    }
  }
}
