import 'dart:async';

import 'package:chaput/features/user/application/profile_controller.dart';
import 'package:chaput/features/user/data/profile_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ProfileApi extends ProfileApi {
  _ProfileApi() : super(Dio());

  Completer<Map<String, dynamic>>? refresh;

  @override
  Future<Map<String, dynamic>> getProfile(String userIdHex) async =>
      refresh?.future ??
      {
        'ok': true,
        'user': {'id': userIdHex},
        'viewer_state': {'is_following': false},
      };

  @override
  Future<Map<String, dynamic>> getTree(String userIdHex) async => {
    'ok': true,
    'tree_id': 'tree_001',
  };
}

void main() {
  test(
    'approval refresh keeps profile identity and tree while fetching',
    () async {
      final api = _ProfileApi();
      final container = ProviderContainer(
        overrides: [profileApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      final provider = profileControllerProvider('private-user');
      final observed = <ProfileState>[];
      container.listen(provider, (_, next) => observed.add(next));
      await Future<void>.delayed(Duration.zero);
      final previous = container.read(provider);
      expect(previous.profileJson, isNotNull);

      observed.clear();
      api.refresh = Completer<Map<String, dynamic>>();
      final pending = container.read(provider.notifier).refetch();
      final loading = container.read(provider);
      expect(loading.isLoading, isTrue);
      expect(loading.profileJson, same(previous.profileJson));
      expect(loading.treeId, previous.treeId);

      api.refresh!.complete({
        'ok': true,
        'user': {'id': 'private-user'},
        'viewer_state': {'is_following': true},
      });
      await pending;

      expect(container.read(provider).isLoading, isFalse);
      expect(
        container.read(provider).profileJson!['viewer_state']['is_following'],
        isTrue,
      );
      expect(observed, isNotEmpty);
      for (final state in observed) {
        expect(state.profileJson!['user']['id'], 'private-user');
        expect(state.treeId, 'tree_001');
      }
    },
  );
}
