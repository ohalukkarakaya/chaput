import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/chaput_circle_avatar/chaput_circle_avatar.dart';
import '../application/user_search_controller.dart';
import 'package:chaput/core/constants/app_colors.dart';
import 'package:chaput/core/i18n/app_localizations.dart';
import 'package:chaput/core/router/routes.dart';
import 'package:go_router/go_router.dart';

class SearchOverlay extends ConsumerStatefulWidget {
  const SearchOverlay({super.key});

  static const heroTag = 'chaput_search_bar';

  @override
  ConsumerState<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends ConsumerState<SearchOverlay> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scroll = ScrollController();

  Timer? _debounce;

  @override
  void initState() {
    super.initState();

    // her açılışta önceki sonuçları sil
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userSearchControllerProvider.notifier).clear();
      if (mounted) _focusNode.requestFocus();
    });

    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      if (pos.pixels >= pos.maxScrollExtent - 240) {
        ref.read(userSearchControllerProvider.notifier).loadMore().then((_) {
          _ensureScrollableIfHasMore();
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();

    final q = value.trim();

    // ✅ min char = 1
    if (q.isEmpty) {
      ref.read(userSearchControllerProvider.notifier).clear();
      return;
    }

    _debounce = Timer(const Duration(seconds: 1), () async {
      await ref.read(userSearchControllerProvider.notifier).searchFirstPage(q);
      _ensureScrollableIfHasMore(); // ✅ limit=2’de bile devam et
    });
  }

  void _ensureScrollableIfHasMore() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!_scroll.hasClients) return;

      final s = ref.read(userSearchControllerProvider);

      // daha fazla yoksa dur
      if (!s.hasMore) return;

      // zaten yükleniyorsa dur
      if (s.isLoading || s.isLoadingMore) return;

      final pos = _scroll.position;

      // ✅ scroll oluşmamışsa (maxScrollExtent ~ 0), otomatik devam
      if (pos.maxScrollExtent <= 0) {
        await ref.read(userSearchControllerProvider.notifier).loadMore();
        // hala scroll yoksa tekrar kontrol et (cursor bitene kadar)
        _ensureScrollableIfHasMore();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userSearchControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.chaputTransparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ✅ blur bariyer + dismiss
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(color: AppColors.chaputTransparent),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),

                // ✅ Hero input
                Hero(
                  tag: SearchOverlay.heroTag,
                  child: Material(
                    color: AppColors.chaputTransparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.chaputWhite.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        child: Row(
                          children: [
                            const Icon(Icons.search, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                autofocus: true,
                                onChanged: _onChanged,
                                textInputAction: TextInputAction.search,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: context.t('search.hint'),
                                  isDense: true,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Expanded(
                  child: _ResultsList(state: state, scroll: _scroll),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  final UserSearchState state;
  final ScrollController scroll;

  const _ResultsList({required this.state, required this.scroll});

  @override
  Widget build(BuildContext context) {
    // ✅ arama yapılmadı: ortada ikon
    if (state.query.trim().isEmpty) {
      return Center(
        child: Icon(Icons.search_rounded, size: 56, color: AppColors.chaputWhite.withOpacity(0.55)),
      );
    }

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Text(
          '${context.t('common.error')}: ${state.error}',
          style: const TextStyle(color: AppColors.chaputWhite),
        ),
      );
    }

    // ✅ arama var ama sonuç yok: ortada ikon + mesaj
    if (state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search_rounded, size: 56, color: AppColors.chaputWhite.withOpacity(0.65)),
            const SizedBox(height: 12),
            Text(
              context.t('search.no_users'),
              style: TextStyle(
                color: AppColors.chaputWhite.withOpacity(0.85),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.t('search.try_different'),
              style: TextStyle(
                color: AppColors.chaputWhite.withOpacity(0.60),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: state.items.length + 1,
      itemBuilder: (context, i) {
        if (i == state.items.length) {
          return state.isLoadingMore
              ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
              : const SizedBox(height: 12);
        }

        final u = state.items[i];

        return InkWell(
          onTap: () async {
            final id = u.id;
            if (id.isEmpty) return;
            Navigator.of(context).pop();
            context.push(await Routes.profile(id));
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.chaputWhite.withOpacity(0.92),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                // Avatar
                ChaputCircleAvatar(
                  isDefaultAvatar: u.profilePhotoKey == null,
                  imageUrl: u.profilePhotoUrl ?? u.defaultAvatar,
                  width: 42,
                  height: 42,
                  radius: 999,
                  borderWidth: 2,
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        u.username == null ? context.t('common.na') : '@${u.username}',
                        style: TextStyle(color: AppColors.chaputBlack.withOpacity(0.55)),
                      ),
                    ],
                  ),
                ),

                if (!u.isPublic)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.chaputBlack,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      context.t('search.private'),
                      style: const TextStyle(color: AppColors.chaputWhite, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
