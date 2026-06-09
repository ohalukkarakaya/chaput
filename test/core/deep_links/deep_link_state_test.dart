import 'package:chaput/core/deep_links/deep_link_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps web profile username links', () {
    final target = chaputDeepLinkTargetFromUri(
      Uri.parse('https://chaput.app/me/melis14'),
    );

    expect(target?.location, '/me/melis14');
  });

  test('maps Android browser fallback custom-scheme links', () {
    final target = chaputDeepLinkTargetFromUri(
      Uri.parse('app.chaput://chaput.app/me/melis14'),
    );

    expect(target?.location, '/me/melis14');
  });

  test('maps legacy host-root custom-scheme links', () {
    final target = chaputDeepLinkTargetFromUri(
      Uri.parse('app.chaput://me/melis14'),
    );

    expect(target?.location, '/me/melis14');
  });

  test('maps notification profile targets with query params', () {
    final target = chaputDeepLinkTargetFromUri(
      Uri.parse('app.chaput://chaput.app/profile/USER123?thread_id=THREAD456'),
    );

    expect(target?.location, '/profile/USER123?thread_id=THREAD456');
  });
}
