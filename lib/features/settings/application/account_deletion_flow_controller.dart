import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccountDeletionFlowState {
  const AccountDeletionFlowState({this.reason});

  final String? reason;

  bool get hasPendingDeletion => reason != null && reason!.trim().isNotEmpty;
}

final accountDeletionFlowControllerProvider =
    NotifierProvider<AccountDeletionFlowController, AccountDeletionFlowState>(
      AccountDeletionFlowController.new,
    );

class AccountDeletionFlowController extends Notifier<AccountDeletionFlowState> {
  @override
  AccountDeletionFlowState build() => const AccountDeletionFlowState();

  void setPending({required String reason}) {
    state = AccountDeletionFlowState(reason: reason.trim());
  }

  void clear() {
    state = const AccountDeletionFlowState();
  }
}
