import 'package:chaput/features/profile/presentation/profile_composer_visibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'keeps new chaput composer visible when profile already has chaputs',
    () {
      expect(
        shouldShowProfileComposer(
          composerOpen: true,
          silhouetteMode: false,
          chaputAllowed: true,
          isMe: false,
          chaputThreadCount: 3,
        ),
        isTrue,
      );
    },
  );

  test('keeps new chaput composer visible from an existing ad page', () {
    expect(
      shouldShowProfileComposer(
        composerOpen: true,
        silhouetteMode: false,
        chaputAllowed: true,
        isMe: false,
        chaputThreadCount: 2,
      ),
      isTrue,
    );
  });

  test('hides composer for blocked profile states', () {
    expect(
      shouldShowProfileComposer(
        composerOpen: true,
        silhouetteMode: true,
        chaputAllowed: true,
        isMe: false,
        chaputThreadCount: 0,
      ),
      isFalse,
    );
    expect(
      shouldShowProfileComposer(
        composerOpen: true,
        silhouetteMode: false,
        chaputAllowed: false,
        isMe: false,
        chaputThreadCount: 0,
      ),
      isFalse,
    );
    expect(
      shouldShowProfileComposer(
        composerOpen: true,
        silhouetteMode: false,
        chaputAllowed: true,
        isMe: true,
        chaputThreadCount: 0,
      ),
      isFalse,
    );
  });
}
