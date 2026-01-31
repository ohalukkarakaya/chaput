import 'package:chaput/core/ui/chaput_circle_avatar/chaput_circle_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/visibility_controller.dart';
import '../../domain/visibility_item.dart';

class BlockedRestrictedScreen extends ConsumerWidget {
  const BlockedRestrictedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(visibilityControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xffEEF2F6),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('‹ Back', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => ref.read(visibilityControllerProvider.notifier).refresh(),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Blocked & Restricted',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                          ),
                          if (st.isLoading)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: st.error != null
                          ? Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Error: ${st.error}', style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => ref.read(visibilityControllerProvider.notifier).refresh(),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                          : (st.items.isEmpty && !st.isLoading)
                          ? const Center(
                              child: Text(
                                'Hiç yok',
                                style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black54),
                              ),
                            )
                          : NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 220) {
                            ref.read(visibilityControllerProvider.notifier).loadMore();
                          }
                          return false;
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          itemCount: st.items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final it = st.items[i];
                            final u = st.usersById[it.userId];

                            final title = u?.fullName ?? '—';
                            final username = u?.username;
                            final avatarUrl = (u?.profilePhotoPath?.isNotEmpty == true)
                                ? u!.profilePhotoPath!
                                : (u?.defaultAvatar ?? '');

                            return _UserRow(
                              title: title,
                              subtitle: username == null || username.isEmpty ? it.userId : '@$username',
                              avatarUrl: avatarUrl.toString(),
                              isDefaultAvatar: u?.profilePhotoPath == null || u?.profilePhotoPath == '',
                              createdAt: it.createdAt,
                              kind: it.kind,
                              userId: it.userId,
                              username: username,
                            );
                          },
                        ),
                      ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserRow extends ConsumerWidget {
  final String title;
  final String subtitle;
  final String avatarUrl;
  final bool isDefaultAvatar;
  final int createdAt;
  final VisibilityKind kind;
  final String userId;
  final String? username;

  const _UserRow({
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.isDefaultAvatar,
    required this.createdAt,
    required this.kind,
    required this.userId,
    required this.username,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chipText = (kind == VisibilityKind.blocked) ? 'Blocked' : 'Restricted';
    final chipBg = (kind == VisibilityKind.blocked)
        ? Colors.red.withOpacity(0.10)
        : Colors.orange.withOpacity(0.12);
    final chipFg = (kind == VisibilityKind.blocked) ? Colors.red.shade700 : Colors.orange.shade800;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          // Avatar (şimdilik basit circle, sen projede ChaputCircleAvatar ile değiştirirsin)
          ChaputCircleAvatar(
            isDefaultAvatar: isDefaultAvatar,
            imageUrl: avatarUrl,
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.black.withOpacity(0.55), fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(7)),
            child: Text(chipText, style: TextStyle(color: chipFg, fontWeight: FontWeight.w900, fontSize: 12)),
          ),

          const SizedBox(width: 10),

          // “Remove” (sonra eklenecekmiş gibi tasarla)
          TextButton(
            onPressed: () async {
              try {
                await ref.read(visibilityControllerProvider.notifier).removeVisibility(
                  userId: userId,
                  kind: kind,
                  username: username,
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Remove failed: $e')),
                );
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  final Widget child;
  const _WhiteCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            blurRadius: 26,
            offset: const Offset(0, 14),
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: child,
    );
  }
}
