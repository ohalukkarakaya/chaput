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
      if (e is DioException && e.response?.statusCode == 403) {
        context.go(Routes.home);
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
