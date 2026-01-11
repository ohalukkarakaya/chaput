import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/user_search_controller.dart';

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
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ✅ arka plan blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(color: Colors.black.withOpacity(0.15)),
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
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white,
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
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Search users...',
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
      return const Center(child: CircularProgressIndicator());
    }

    if ((state.query.trim().length <= 5)) {
      return const Center(
        child: Text(
          'Type at least 6 characters…',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: Text(
          'Error: ${state.error}',
          style: const TextStyle(color: Colors.white),
        ),
      );
    }

    if (state.items.isEmpty) {
      return const Center(
        child: Text(
          'No users found.',
          style: TextStyle(color: Colors.white),
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

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // ✅ Avatar placeholder (sonra ChaputCircleAvatar bağlarız)
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Colors.black12,
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
                      u.username == null ? '—' : '@${u.username}',
                      style: TextStyle(color: Colors.black.withOpacity(0.55)),
                    ),
                  ],
                ),
              ),
              if (!u.isPublic)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Private',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}