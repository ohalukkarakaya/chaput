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

    if (s.contains('missing_new_email')) return 'Yeni e-posta gerekli.';
    if (s.contains('missing_fields')) return 'Eksik alan var.';
    if (s.contains('invalid_email')) return 'E-posta formatı hatalı.';
    if (s.contains('email_taken')) return 'Bu e-posta zaten kullanımda.';
    if (s.contains('rate_limited')) return 'Çok hızlı deniyorsun. Biraz bekleyip tekrar dene.';
    if (s.contains('code_not_found')) return 'Kod bulunamadı. Yeniden kod iste.';
    if (s.contains('code_expired')) return 'Kodun süresi doldu. Yeniden kod iste.';
    if (s.contains('invalid_code')) return 'Kod yanlış. Tekrar dene.';
    if (s.contains('too_many_attempts')) return 'Çok fazla deneme. Bir süre bekle.';
    if (s.contains('db_error')) return 'Sunucu hatası. Tekrar dene.';
    if (s.contains('unauthorized')) return 'Oturum hatası. Tekrar giriş yapman gerekebilir.';

    final code = e.response?.statusCode;
    return 'Hata ($code). Tekrar dene.';
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
      state = state.copyWith(isLoading: false, errorMessage: 'Bir şey ters gitti. Tekrar dene.');
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
      state = state.copyWith(isLoading: false, errorMessage: 'Bir şey ters gitti. Tekrar dene.');
      return (ok: false, errorText: 'Bir şey ters gitti. Tekrar dene.', lockSeconds: null);
    }
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: null);
    }
  }
}