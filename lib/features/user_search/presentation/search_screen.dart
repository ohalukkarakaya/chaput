import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/user_search_controller.dart';
import 'package:chaput/core/constants/app_colors.dart';
import 'package:chaput/core/i18n/app_localizations.dart';
import 'package:chaput/core/ui/widgets/shimmer_skeleton.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  static const heroTag = 'chaput_search_bar';

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scroll = ScrollController();

  Timer? _debounce;

  @override
  void initState() {
    super.initState();

    // ✅ otomatik focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });

    // ✅ pagination trigger
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      if (pos.pixels >= pos.maxScrollExtent - 240) {
        ref.read(userSearchControllerProvider.notifier).loadMore();
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
    if (q.length <= 5) {
      ref.read(userSearchControllerProvider.notifier).searchFirstPage(q);
      return;
    }

    // ✅ kullanıcı yazmayı bıraktıktan sonra 1s
    _debounce = Timer(const Duration(seconds: 1), () {
      ref.read(userSearchControllerProvider.notifier).searchFirstPage(q);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userSearchControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.chaputTransparent,
      body: Stack(
        children: [
          // ✅ arka plan blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(color: AppColors.chaputBlack.withOpacity(0.15)),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),

                // ✅ Hero ile büyüyen search input
                Hero(
                  tag: SearchScreen.heroTag,
                  child: Material(
                    color: AppColors.chaputTransparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.chaputWhite,
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

                // ✅ sonuç listesi
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
    if (state.isLoading) {
      final cardBg = AppColors.chaputWhite.withOpacity(0.12);
      return ShimmerLoading(
        baseColor: AppColors.chaputWhite.withOpacity(0.10),
        highlightColor: AppColors.chaputWhite.withOpacity(0.28),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: 6,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, __) => ShimmerUserCard(
            backgroundColor: cardBg,
            line1Factor: 0.58,
            line2Factor: 0.35,
          ),
        ),
      );
    }

    if ((state.query.trim().length <= 5)) {
      return Center(
        child: Text(
          context.t('search.min_chars'),
          style: const TextStyle(color: AppColors.chaputWhite),
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: Text(
          '${context.t('common.error')}: ${state.error}',
          style: const TextStyle(color: AppColors.chaputWhite),
        ),
      );
    }

    if (state.items.isEmpty) {
      return Center(
        child: Text(
          context.t('search.no_users'),
          style: const TextStyle(color: AppColors.chaputWhite),
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
              ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: ShimmerLoading(
              baseColor: AppColors.chaputWhite.withOpacity(0.10),
              highlightColor: AppColors.chaputWhite.withOpacity(0.28),
              child: const ShimmerLine(width: 140, height: 10),
            ),
          )
              : const SizedBox(height: 12);
        }

        final u = state.items[i];

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.chaputWhite.withOpacity(0.92),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // ✅ Avatar placeholder (sonra ChaputCircleAvatar bağlarız)
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.chaputBlack12,
                  shape: BoxShape.circle,
                ),
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
        );
      },
    );
  }
}
