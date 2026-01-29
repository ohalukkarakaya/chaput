import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';
import '../data/chaput_api.dart';
import '../domain/chaput_decision.dart';

class ChaputDecisionState {
  const ChaputDecisionState({
    this.isLoading = false,
    this.decision,
    this.error,
  });

  final bool isLoading;
  final ChaputDecision? decision;
  final String? error;

  ChaputDecisionState copyWith({
    bool? isLoading,
    ChaputDecision? decision,
    String? error,
    bool clearError = false,
  }) {
    return ChaputDecisionState(
      isLoading: isLoading ?? this.isLoading,
      decision: decision ?? this.decision,
      error: clearError ? null : (error ?? this.error),
    );
  }

  static const empty = ChaputDecisionState();
}

final chaputApiProvider = Provider<ChaputApi>((ref) {
  final dio = ref.read(dioProvider);
  return ChaputApi(dio);
});

final chaputDecisionControllerProvider =
    AutoDisposeNotifierProviderFamily<ChaputDecisionController, ChaputDecisionState, String>(
  ChaputDecisionController.new,
);

class ChaputDecisionController extends AutoDisposeFamilyNotifier<ChaputDecisionState, String> {
  ChaputApi get _api => ref.read(chaputApiProvider);

  @override
  ChaputDecisionState build(String profileIdHex) {
    return ChaputDecisionState.empty;
  }

  Future<ChaputDecision?> fetchDecisionAndReturn() async {
    if (state.isLoading) return state.decision;
    state = state.copyWith(isLoading: true, error: null, clearError: true);
    try {
      final decision = await _api.getDecision(arg);
      state = state.copyWith(isLoading: false, decision: decision, clearError: true);
      return decision;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return state.decision;
    }
  }


  Future<void> fetchDecision() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null, clearError: true);
    try {
      final decision = await _api.getDecision(arg);
      state = state.copyWith(isLoading: false, decision: decision, clearError: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void applyCreditsDelta({
    int normal = 0,
    int hidden = 0,
    int special = 0,
    int revive = 0,
    int whisper = 0,
  }) {
    final current = state.decision;
    if (current == null) return;
    final credits = current.credits;

    final next = credits.copyWith(
      normal: math.max(0, credits.normal + normal),
      hidden: math.max(0, credits.hidden + hidden),
      special: math.max(0, credits.special + special),
      revive: math.max(0, credits.revive + revive),
      whisper: math.max(0, credits.whisper + whisper),
    );

    state = state.copyWith(decision: current.copyWith(credits: next));
  }

  void applyPlanType(String type) {
    final current = state.decision;
    if (current == null) return;
    state = state.copyWith(decision: current.copyWith(plan: current.plan.copyWith(type: type)));
  }

  void applyPlanPeriod(String period) {
    final current = state.decision;
    if (current == null) return;
    state = state.copyWith(decision: current.copyWith(plan: current.plan.copyWith(period: period)));
  }

  void setCredits({
    required int normal,
    required int hidden,
    required int special,
    required int revive,
    required int whisper,
  }) {
    final current = state.decision;
    if (current == null) return;
    state = state.copyWith(
      decision: current.copyWith(
        credits: current.credits.copyWith(
          normal: normal,
          hidden: hidden,
          special: special,
          revive: revive,
          whisper: whisper,
        ),
      ),
    );
  }

  void applyAdsWatched(int watched) {
    // Deprecated: ad rewards are now tracked server-side; use fetchDecision().
    // ignore: unnecessary_statements
    watched;
  }
}
