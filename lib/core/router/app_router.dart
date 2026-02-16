import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/screens/home_shell.dart';
import '../../features/onboarding/presentation/screens/boot_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/profile_username_redirect_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';


import '../network/dio_provider.dart';
import 'routes.dart';
import 'route_observer.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.boot,
    observers: [routeObserver],
    routes: [
      GoRoute(
        path: Routes.boot,
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const BootScreen(),
        ),
      ),
      GoRoute(
        path: Routes.onboarding,
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: Routes.home,
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const HomeShell(),
        ),
      ),
      GoRoute(
        path: '/me/:username',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: ProfileUsernameRedirectScreen(
            username: state.pathParameters['username']!,
          ),
        ),
      ),
      GoRoute(
        name: 'profile',
        path: '/profile/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          String? initialThreadId;
          String? initialMessageId;
          final extra = state.extra;
          if (extra is Map) {
            final threadId = extra['threadId'];
            if (threadId is String && threadId.isNotEmpty) {
              initialThreadId = threadId;
            }
            final messageId = extra['messageId'];
            if (messageId is String && messageId.isNotEmpty) {
              initialMessageId = messageId;
            }
          }
          return ProfileScreen(
            key: ValueKey('profile-$userId'),
            userId: userId,
            initialThreadId: initialThreadId,
            initialMessageId: initialMessageId,
          );
        },
      ),
      GoRoute(
        path: Routes.login,
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: Routes.register,
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: Routes.settings,
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: Routes.notifications,
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const NotificationsScreen(),
        ),
      ),
    ],
  );
});

CustomTransitionPage _fadePage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: child,
      );
    },
  );
}
