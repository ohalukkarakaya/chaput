import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/storage/secure_storage_provider.dart';
import '../../../user/application/profile_controller.dart';
import '../widgets/tree_silhouette_shimmer.dart';

class ProfileUsernameRedirectScreen extends ConsumerStatefulWidget {
  const ProfileUsernameRedirectScreen({
    super.key,
    required this.username,
    this.initialThreadId,
    this.initialMessageId,
  });

  final String username;
  final String? initialThreadId;
  final String? initialMessageId;

  @override
  ConsumerState<ProfileUsernameRedirectScreen> createState() =>
      _ProfileUsernameRedirectScreenState();
}

class _ProfileUsernameRedirectScreenState
    extends ConsumerState<ProfileUsernameRedirectScreen> {
  bool _handled = false;
  String? _error;

  bool _isUnavailableProfileError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 403 || status == 404) return true;
      final data = error.response?.data;
      final code = data is Map
          ? data['error']?.toString() ?? ''
          : data?.toString() ?? '';
      return _isUnavailableProfileCode(code);
    }
    return _isUnavailableProfileCode(error.toString());
  }

  bool _isUnavailableProfileCode(String code) {
    return code.contains('user_not_found') ||
        code.contains('profile_not_found') ||
        code.contains('blocked') ||
        code.contains('forbidden') ||
        code.contains('shadow') ||
        code.contains('invalid_username') ||
        code.contains('bad_username_response');
  }

  void _showUserNotFoundAndGoHome() {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(context.t('errors.user_not_found'))),
    );
    context.go(Routes.home);
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_resolve);
  }

  Future<void> _resolve() async {
    if (_handled) return;
    _handled = true;

    final storage = ref.read(tokenStorageProvider);
    final refresh = await storage.readRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      if (!mounted) return;
      context.go(Routes.onboarding);
      return;
    }

    final api = ref.read(profileApiProvider);
    try {
      final res = await api.resolveUsername(widget.username);
      await api.getProfile(res.userId);
      if (!mounted) return;
      final extra = <String, String>{};
      final threadId = widget.initialThreadId;
      final messageId = widget.initialMessageId;
      if (threadId != null && threadId.isNotEmpty) {
        extra['threadId'] = threadId;
      }
      if (messageId != null && messageId.isNotEmpty) {
        extra['messageId'] = messageId;
      }
      context.pushReplacement(
        '/profile/${res.userId}',
        extra: extra.isEmpty ? null : extra,
      );
    } catch (e) {
      if (!mounted) return;
      if (e is DioException && e.response?.statusCode == 401) {
        context.go(Routes.onboarding);
        return;
      }
      if (_isUnavailableProfileError(e)) {
        _showUserNotFoundAndGoHome();
        return;
      }
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.chaputCloudBlue,
      body: Center(
        child: _error == null
            ? const TreeSilhouetteShimmer(size: 170)
            : Text(
                context.t('errors.generic'),
                style: const TextStyle(
                  color: AppColors.chaputBlack,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
