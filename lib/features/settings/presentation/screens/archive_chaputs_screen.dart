import 'package:chaput/core/ui/chaput_circle_avatar/chaput_circle_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/archive_controller.dart';

class ArchiveChaputsScreen extends ConsumerWidget {
  const ArchiveChaputsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(archiveControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xffEEF2F6),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
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
                        onPressed: () => ref.read(archiveControllerProvider.notifier).refresh(),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  _WhiteCard(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Archived chaputs',
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
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: _WhiteCard(
                      child: st.error != null
                          ? Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(st.error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => ref.read(archiveControllerProvider.notifier).refresh(),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                          : NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 220) {
                            ref.read(archiveControllerProvider.notifier).loadMore();
                          }
                          return false;
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          itemCount: st.items.length + 1,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            if (i == st.items.length) {
                              if (st.isLoadingMore) {
                                return const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Center(
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox(height: 6);
                            }

                            final it = st.items[i];
                            final u = st.usersById[it.authorId];

                            final fullName = u?.fullName ?? '—';
                            final username = u?.username;
                            final defaultAvatar = u?.defaultAvatar ?? '';
                            final imgUrl = (u?.profilePhotoPath != null && u!.profilePhotoPath!.isNotEmpty)
                                ? u.profilePhotoPath
                                : defaultAvatar;

                            final isDefault = u?.profilePhotoPath == null || u?.profilePhotoPath == '';

                            final isBusy = st.revivingChaputId == it.id;

                            return _ArchivedRow(
                              fullName: fullName,
                              subtitle: username == null || username.isEmpty ? it.authorId : '@$username',
                              avatarUrl: imgUrl.toString(),
                              isDefaultAvatar: isDefault,
                              text: it.text ?? '',
                              onRevive: isBusy
                                  ? null
                                  : () async {
                                final ok = await ref.read(archiveControllerProvider.notifier).revive(it.id);
                                if (!context.mounted) return;
                                if (ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Chaput revived ✅')),
                                  );
                                }
                              },
                              busy: isBusy,
                            );
                          },
                        ),
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

class _ArchivedRow extends StatelessWidget {
  final String fullName;
  final String subtitle;
  final String avatarUrl;
  final bool isDefaultAvatar;
  final String text;
  final VoidCallback? onRevive;
  final bool busy;

  const _ArchivedRow({
    required this.fullName,
    required this.subtitle,
    required this.avatarUrl,
    required this.isDefaultAvatar,
    required this.text,
    required this.onRevive,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChaputCircleAvatar(
            width: 44,
            height: 44,
            radius: 999,
            borderWidth: 2,
            bgColor: Colors.black,
            isDefaultAvatar: isDefaultAvatar,
            imageUrl: avatarUrl,
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fullName, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.black.withOpacity(0.55), fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  text.isEmpty ? '—' : text,
                  style: const TextStyle(fontSize: 14, height: 1.25, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: onRevive,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Revive', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
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
