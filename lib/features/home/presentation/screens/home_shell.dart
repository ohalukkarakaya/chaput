import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/storage/secure_storage_provider.dart';
import '../../../auth/data/auth_api.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final storage = ref.read(tokenStorageProvider);
            final refresh = await storage.readRefreshToken();

            if (refresh == null || refresh.isEmpty) {
              // zaten yoksa onboarding'e at
              if (context.mounted) context.go(Routes.onboarding);
              return;
            }

            try {
              final api = ref.read(authApiProvider);
              await api.logout(refreshToken: refresh);

              // 200 geldiyse lokal refresh/access temizle
              await storage.clear();
              if (context.mounted) context.go(Routes.onboarding);
            } on DioException {
              // 401 invalid_refresh_token olsa bile lokal temizleyip onboarding’e atmak mantıklı
              await storage.clear();
              if (context.mounted) context.go(Routes.onboarding);
            } catch (_) {
              await storage.clear();
              if (context.mounted) context.go(Routes.onboarding);
            }
          },
          child: const Text('Logout'),
        ),
      ),
    );
  }
}