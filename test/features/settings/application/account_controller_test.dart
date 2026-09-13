import 'dart:async';

import 'package:chaput/features/settings/application/account_controller.dart';
import 'package:chaput/features/settings/data/account_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _DelayedAccountApi extends AccountApi {
  _DelayedAccountApi() : super(Dio());

  final response = Completer<void>();

  @override
  Future<void> deleteMeHard({required String reason}) => response.future;

  @override
  Future<void> freezeMe() => response.future;
}

void main() {
  for (final freeze in [false, true]) {
    for (final fails in [false, true]) {
      test(
        '${freeze ? 'freeze' : 'delete'} preserves delayed '
        '${fails ? 'failure' : 'success'} without a provider listener',
        () async {
          final api = _DelayedAccountApi();
          final container = ProviderContainer(
            overrides: [accountApiProvider.overrideWithValue(api)],
          );
          addTearDown(container.dispose);
          final controller = container.read(accountControllerProvider.notifier);
          final request = freeze
              ? controller.freezeMe()
              : controller.deleteMeHard(reason: 'Test account removal');
          final error = StateError('Server rejected the operation');
          final expectation = expectLater(
            request,
            fails ? throwsA(same(error)) : completes,
          );

          // Settings only reads the notifier; let auto-dispose run during HTTP.
          await container.pump();
          if (fails) {
            api.response.completeError(error);
          } else {
            api.response.complete();
          }
          await expectation;
        },
      );
    }
  }
}
