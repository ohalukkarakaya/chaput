import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/storage/secure_storage_provider.dart';
import '../../../user/application/profile_controller.dart';

class ProfileUsernameRedirectScreen extends ConsumerStatefulWidget {
  const ProfileUsernameRedirectScreen({
    super.key,
    required this.username,
  });

  final String username;

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
      if (!mounted) return;
      context.go('/profile/${res.userId}');
    } catch (e) {
      if (!mounted) return;
      if (e is DioException && e.response?.statusCode == 401) {
        context.go(Routes.onboarding);
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
      body: Center(
        child: _error == null
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('User not found'),
      ),
    );
  }
}
