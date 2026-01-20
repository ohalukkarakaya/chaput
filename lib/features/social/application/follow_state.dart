sealed class FollowState {
  const FollowState();
}

class FollowIdle extends FollowState {
  const FollowIdle({
    this.isFollowing,
    this.requestPending,
  });

  final bool? isFollowing;
  final bool? requestPending;
}

class FollowLoading extends FollowState {
  const FollowLoading();
}

class FollowError extends FollowState {
  const FollowError(this.message);
  final String message;
}
