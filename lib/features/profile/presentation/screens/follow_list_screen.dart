import 'package:chaput/core/ui/chaput_circle_avatar/chaput_circle_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../social/application/follow_list_controller.dart';
import '../../../../core/router/routes.dart';

class FollowListScreen extends ConsumerStatefulWidget {
  const FollowListScreen({
    super.key,
    required this.username,
    required this.kind,
    required this.isMe,
    required this.title,
  });

  final String username;
  final FollowListKind kind;
  final bool isMe;
  final String title;

  @override
  ConsumerState<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends ConsumerState<FollowListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  late final FollowListArgs _args;

  @override
  void initState() {
    super.initState();
    _args = FollowListArgs(username: widget.username, kind: widget.kind);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(followListControllerProvider(_args));

    final query = _searchCtrl.text.trim().toLowerCase();
    final items = query.isEmpty
        ? st.items
        : st.items.where((e) {
      final u = st.usersById[e.userId];
      final name = (u?.fullName ?? e.fullName).toLowerCase();
      final username = (u?.username ?? e.username).toLowerCase();
      return name.contains(query) || username.contains(query);
    }).toList(growable: false);

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
                        onPressed: () => ref.read(followListControllerProvider(_args).notifier).refresh(),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.title,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
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

                  if (widget.isMe) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Ara',
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.96),
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                  ],

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
                          onPressed: () => ref.read(followListControllerProvider(_args).notifier).refresh(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                        : (items.isEmpty && !st.isLoading)
                            ? Center(
                                child: Text(
                                  'Kimse yok',
                                  style: TextStyle(
                                    color: Colors.black.withOpacity(0.55),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : RefreshIndicator(
                            onRefresh: () => ref.read(followListControllerProvider(_args).notifier).refresh(),
                            child: NotificationListener<ScrollNotification>(
                              onNotification: (n) {
                                if (st.isLoading || !st.hasMore) return false;
                                if (n.metrics.maxScrollExtent <= 0) return false;
                                if (n.metrics.pixels >= n.metrics.maxScrollExtent - 220) {
                                  ref.read(followListControllerProvider(_args).notifier).loadMore();
                                }
                                return false;
                              },
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                itemCount: items.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, i) {
                                  final it = items[i];
                                  final u = st.usersById[it.userId];

                                  final title = u?.fullName.isNotEmpty == true
                                      ? u!.fullName
                                      : (it.fullName.isNotEmpty ? it.fullName : '—');
                                  final uname = (u?.username?.isNotEmpty == true)
                                      ? u!.username
                                      : it.username;

                                  final avatarUrl = (u?.profilePhotoPath?.isNotEmpty == true)
                                      ? u!.profilePhotoPath!
                                      : (u?.defaultAvatar ?? '');
                                  final isDefaultAvatar = u?.profilePhotoPath == null || u?.profilePhotoPath == '';

                                  return _FollowRow(
                                    title: title,
                                    subtitle: (uname?.isEmpty ?? true) ? it.userId : '@$uname',
                                    avatarUrl: avatarUrl.toString(),
                                    isDefaultAvatar: isDefaultAvatar,
                                    canOpen: it.canOpenProfile,
                                    onTap: () async {
                                      if (!it.canOpenProfile) return;
                                      if (!context.mounted) return;
                                      context.push(await Routes.profile(it.userId));
                                    },
                                    showRemove: widget.isMe && widget.kind == FollowListKind.followers,
                                    onRemove: () async {
                                      if (!widget.isMe || (uname?.isEmpty ?? true)) return;
                                      try {
                                        await ref.read(followListControllerProvider(_args).notifier).removeFollower(
                                          ownerUsername: widget.username,
                                          followerUsername: uname ?? '',
                                          followerId: it.userId,
                                        );
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Remove failed: $e')),
                                        );
                                      }
                                    },
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

class _FollowRow extends StatelessWidget {
  const _FollowRow({
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.isDefaultAvatar,
    required this.canOpen,
    required this.onTap,
    required this.showRemove,
    required this.onRemove,
  });

  final String title;
  final String subtitle;
  final String avatarUrl;
  final bool isDefaultAvatar;
  final bool canOpen;
  final VoidCallback onTap;
  final bool showRemove;
  final VoidCallback onRemove;

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
        children: [
          ChaputCircleAvatar(
            isDefaultAvatar: isDefaultAvatar,
            imageUrl: avatarUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: canOpen ? onTap : null,
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
          ),
          if (showRemove) ...[
            const SizedBox(width: 10),
            TextButton(
              onPressed: onRemove,
              child: const Text('Kaldır'),
            ),
          ],
        ],
      ),
    );
  }
}
