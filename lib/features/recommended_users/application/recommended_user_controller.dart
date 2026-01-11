import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/recommended_users_api.dart';
import '../domain/recommended_user.dart';

final recommendedUserControllerProvider =
AsyncNotifierProvider<RecommendedUserController, RecommendedUser?>(
  RecommendedUserController.new,
);

class RecommendedUserController extends AsyncNotifier<RecommendedUser?> {
  @override
  Future<RecommendedUser?> build() async {
    // Home açılınca otomatik çek
    return _fetch();
  }

  Future<RecommendedUser?> _fetch() async {
    final api = ref.read(recommendedUsersApiProvider);
    final u = await api.getRecommended();
    return u;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}