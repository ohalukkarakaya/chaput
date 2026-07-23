import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_visit_history_controller.dart';
import '../../profile/domain/profile_preview.dart';
import '../../profile/presentation/widgets/profile_avatar_hero.dart';
import '../../recommended_users/presentation/widgets/recommended_user_card.dart';
import '../domain/user_search_models.dart';
import '../application/user_search_controller.dart';
import 'package:chaput/core/constants/app_colors.dart';
import 'package:chaput/core/i18n/app_localizations.dart';
import 'package:chaput/core/ui/widgets/empty_state_illustration.dart';
import 'package:chaput/core/ui/widgets/shimmer_skeleton.dart';
import 'package:chaput/core/ui/widgets/app_text_context_menu.dart';
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
  final Set<String> _dismissedDiscoverIds = <String>{};

  Timer? _debounce;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref.read(userSearchControllerProvider.notifier).loadDiscoverFirstPage(),
      );
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

    if (q.isEmpty) {
      unawaited(
        ref.read(userSearchControllerProvider.notifier).loadDiscoverFirstPage(),
      );
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

  Future<void> _openProfile(ProfilePreview preview) async {
    final id = preview.id;
    if (id.isEmpty) return;

    ref.read(profileVisitHistoryProvider.notifier).record(preview);
    final route = ModalRoute.of(context);
    final profileRoute = await Routes.profile(id);
    if (!mounted) return;

    await context.push(profileRoute, extra: {profilePreviewExtraKey: preview});

    if (!mounted) return;
    if (route?.isCurrent == true && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _dismissDiscoverUser(String id) {
    if (id.isEmpty) return;
    setState(() => _dismissedDiscoverIds.add(id));
  }

  void _syncDiscoverFollowState(ProfilePreview user) {
    ref
        .read(userSearchControllerProvider.notifier)
        .updateFollowState(
          userId: user.id,
          isFollowing: user.isFollowing,
          requestPending: user.requestPending,
        );
    ref.read(profileVisitHistoryProvider.notifier).updateFollowState(user);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userSearchControllerProvider);
    final visitHistory = ref.watch(profileVisitHistoryProvider);

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
            bottom: false,
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
                                contextMenuBuilder: appTextContextMenuBuilder,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: context.t('search.hint'),
                                  isDense: true,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                Navigator.of(context).pop();
                              },
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
                  child: _ResultsList(
                    state: state,
                    scroll: _scroll,
                    visitHistory: visitHistory,
                    dismissedDiscoverIds: _dismissedDiscoverIds,
                    onOpenProfile: _openProfile,
                    onDismissDiscoverUser: _dismissDiscoverUser,
                    onFollowStateChanged: _syncDiscoverFollowState,
                  ),
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
  final List<ProfilePreview> visitHistory;
  final Set<String> dismissedDiscoverIds;
  final Future<void> Function(ProfilePreview preview) onOpenProfile;
  final ValueChanged<String> onDismissDiscoverUser;
  final ValueChanged<ProfilePreview> onFollowStateChanged;

  const _ResultsList({
    required this.state,
    required this.scroll,
    required this.visitHistory,
    required this.dismissedDiscoverIds,
    required this.onOpenProfile,
    required this.onDismissDiscoverUser,
    required this.onFollowStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      final cardBg = AppColors.chaputWhite.withOpacity(0.12);
      return ShimmerLoading(
        baseColor: AppColors.chaputWhite.withOpacity(0.10),
        highlightColor: AppColors.chaputWhite.withOpacity(0.28),
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.paddingOf(context).bottom + 48,
          ),
          itemCount: 6,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, __) => ShimmerUserCard(
            backgroundColor: cardBg,
            line1Factor: 0.6,
            line2Factor: 0.38,
          ),
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
      return const EmptyStateIllustration(
        assetPath:
            'assets/images/empty_state/user_search_not_found_empty_state.png',
        maxWidth: 220,
      );
    }

    final isDiscover =
        state.mode == UserSearchMode.discover && state.query.trim().isEmpty;
    final topProfiles = isDiscover
        ? _topDiscoverProfiles(state.items, visitHistory, dismissedDiscoverIds)
        : const <ProfilePreview>[];
    final topProfileIds = {for (final profile in topProfiles) profile.id};
    final listItems = isDiscover
        ? state.items
              .where(
                (item) =>
                    !topProfileIds.contains(item.id) &&
                    !dismissedDiscoverIds.contains(item.id),
              )
              .toList(growable: false)
        : state.items;
    final hasTopRail = topProfiles.isNotEmpty;
    final leadingCount = hasTopRail ? 1 : 0;

    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: leadingCount + listItems.length + 1,
      itemBuilder: (context, i) {
        if (hasTopRail && i == 0) {
          final screenWidth = MediaQuery.sizeOf(context).width;
          final cardWidth = screenWidth < 390 ? screenWidth - 96 : 250.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: SizedBox(
              height: 154,
              child: ListView.separated(
                clipBehavior: Clip.none,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: topProfiles.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final profile = topProfiles[index];
                  return RecommendedUserCard(
                    user: profile,
                    width: cardWidth,
                    onDismiss: onDismissDiscoverUser,
                    onOpenProfile: onOpenProfile,
                    onFollowStateChanged: onFollowStateChanged,
                    heroEnabled: false,
                    dismissOnFollowSuccess: false,
                  );
                },
              ),
            ),
          );
        }

        final listIndex = i - leadingCount;
        if (listIndex == listItems.length) {
          return state.isLoadingMore
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: ShimmerLoading(
                    baseColor: AppColors.chaputWhite.withOpacity(0.10),
                    highlightColor: AppColors.chaputWhite.withOpacity(0.28),
                    child: const ShimmerLine(width: 140, height: 10),
                  ),
                )
              : SizedBox(height: 40);
        }

        final u = listItems[listIndex];
        final preview = _previewFromSearchItem(u);

        return InkWell(
          onTap: () async {
            HapticFeedback.selectionClick();
            await onOpenProfile(preview);
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
                ProfileAvatarHero(
                  preview: preview,
                  width: 42,
                  height: 42,
                  enabled: !isDiscover,
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.fullName,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        u.username == null
                            ? context.t('common.na')
                            : '@${u.username}',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.chaputBlack.withOpacity(0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isDiscover) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onDismissDiscoverUser(u.id);
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.chaputBlack.withOpacity(0.06),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 17,
                        color: AppColors.chaputBlack.withOpacity(0.68),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

List<ProfilePreview> _topDiscoverProfiles(
  List<UserSearchItem> items,
  List<ProfilePreview> visitHistory,
  Set<String> dismissedIds,
) {
  const targetCount = 5;
  final discoverProfilesById = {
    for (final item in items) item.id: _previewFromSearchItem(item),
  };
  final topProfiles = <ProfilePreview>[];
  final seenIds = <String>{};

  void addProfile(ProfilePreview profile) {
    final id = profile.id;
    if (id.isEmpty || dismissedIds.contains(id) || !seenIds.add(id)) return;
    topProfiles.add(profile);
  }

  for (final profile in visitHistory) {
    if (topProfiles.length >= targetCount) break;
    final discoverProfile = discoverProfilesById[profile.id];
    addProfile(
      discoverProfile == null
          ? profile
          : mergeDiscoverProfileState(discoverProfile, profile),
    );
  }

  for (final item in items) {
    if (topProfiles.length >= targetCount) break;
    addProfile(_previewFromSearchItem(item));
  }

  return topProfiles;
}

ProfilePreview mergeDiscoverProfileState(
  ProfilePreview discoverProfile,
  ProfilePreview historyProfile,
) {
  final isFollowing = discoverProfile.isFollowing || historyProfile.isFollowing;
  final requestPending =
      !isFollowing &&
      (discoverProfile.requestPending || historyProfile.requestPending);
  return discoverProfile.copyWith(
    isFollowing: isFollowing,
    requestPending: requestPending,
  );
}

ProfilePreview _previewFromSearchItem(UserSearchItem user) {
  return ProfilePreview(
    id: user.id,
    username: user.username,
    fullName: user.fullName,
    defaultAvatar: user.defaultAvatar,
    profilePhotoKey: user.profilePhotoKey,
    profilePhotoUrl: user.profilePhotoUrl,
    isPublic: user.isPublic,
    requestPending: user.requestPending,
    isFollowing: user.isFollowing,
  );
}
