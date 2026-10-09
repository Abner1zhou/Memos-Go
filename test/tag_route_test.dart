import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:memos_go/app.dart';

void main() {
  late GoRouter router;

  setUp(() {
    router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/memos',
      routes: buildAppRoutes(),
    );
  });

  tearDown(() => router.dispose());

  RouteMatchList matchFor(String location) =>
      router.configuration.findMatch(Uri.parse(location));

  // Repro for `GoException: no routes for location: /memos/tag/Inbox/22`:
  // nested tag values must arrive percent-encoded so they stay a single
  // path segment; raw interpolation splits them into extra segments.
  test('nested tag path resolves to tag route with decoded tag', () {
    final match = matchFor('/memos/tag/${Uri.encodeComponent('Inbox/22')}');
    expect(match.error, isNull);
    expect(match.pathParameters['tag'], 'Inbox/22');
    expect(match.last.route.path, 'tag/:tag');
  });

  test('unencoded nested tag does not match', () {
    // The buggy location from the crash report: an unencoded `Inbox/22`
    // tag adds a fourth segment the route table cannot match.
    final match = matchFor('/memos/tag/Inbox/22');
    expect(match.error, isNotNull);
  });

  test('tags with reserved characters resolve and decode round-trip', () {
    for (final tag in ['hello world', 'C++', '100%', 'a/b#c', '读书/笔记']) {
      final match = matchFor('/memos/tag/${Uri.encodeComponent(tag)}');
      expect(match.error, isNull, reason: tag);
      expect(match.pathParameters['tag'], tag);
    }
  });

  // The composer route takes its prefilled tag as a query parameter and must
  // follow the same percent-encoding rules as tag/:tag.
  test('new memo route matches without a tag', () {
    final match = matchFor('/memos/new');
    expect(match.error, isNull);
    expect(match.last.route.path, 'new');
    expect(match.uri.queryParameters['tag'], isNull);
  });

  test('new memo route prefilled tag decodes round-trip', () {
    for (final tag in ['hello world', 'C++', '100%', 'a/b#c', '读书/笔记']) {
      final match = matchFor('/memos/new?tag=${Uri.encodeComponent(tag)}');
      expect(match.error, isNull, reason: tag);
      expect(match.last.route.path, 'new');
      expect(match.uri.queryParameters['tag'], tag);
    }
  });

  test('unencoded reserved characters corrupt the prefilled tag', () {
    // `#` starts the fragment, so a raw tag silently truncates instead of
    // matching the intended value.
    final match = matchFor('/memos/new?tag=a/b#c');
    expect(match.uri.queryParameters['tag'], 'a/b');
  });
}
