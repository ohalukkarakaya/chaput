bool shouldShowProfileComposer({
  required bool composerOpen,
  required bool silhouetteMode,
  required bool chaputAllowed,
  required bool isMe,
  required int chaputThreadCount,
}) {
  assert(chaputThreadCount >= 0);
  return composerOpen && !silhouetteMode && chaputAllowed && !isMe;
}
