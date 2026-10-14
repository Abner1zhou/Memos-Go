import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/app.dart';
import 'package:memos_go/data/models/models.dart';
import 'package:memos_go/data/repositories/auth_repository.dart';
import 'package:memos_go/data/repositories/memo_repository.dart';
import 'package:memos_go/providers/auth_providers.dart';
import 'package:memos_go/providers/sync_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    final account = ServerAccount(
      id: 'http://x|tester',
      baseUrl: 'http://x',
      token: 'tok',
      user: const User(name: 'users/1', username: 'tester'),
    );
    return AuthState(
      status: AuthStatus.signedIn,
      accounts: [account],
      activeAccount: account,
    );
  }
}

class _FakeMemoRepository extends MemoRepository {
  _FakeMemoRepository()
      : super(ServerAccount(
          id: 'http://x|tester',
          baseUrl: 'http://x',
          token: 'tok',
          user: const User(name: 'users/1', username: 'tester'),
        ));

  @override
  Future<MemoListPage> listMemos({
    int pageSize = 50,
    String pageToken = '',
    String? filter,
  }) async =>
      const MemoListPage(memos: []);

  @override
  Future<UserStats> userStats() async => const UserStats(tagCounts: {});
}

void main() {
  Future<void> pumpHome(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith(_StubAuthNotifier.new),
        memoRepositoryProvider.overrideWith((ref) => _FakeMemoRepository()),
        // The voice capture flow under test doesn't sync; the engine's
        // debounce timer would otherwise outlive the test.
        syncEngineProvider.overrideWithValue(null),
      ],
      child: const MemosGoApp(),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets(
      'long-press on the + FAB prompts ASR setup when voice input is not configured',
      (tester) async {
    await pumpHome(tester);

    await tester.longPress(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('Speech recognition not configured'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long-press on the + FAB keeps the editor behind a plain tap',
      (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Plain tap still routes to the composer, not the voice flow.
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    expect(find.text('Speech recognition not configured'), findsNothing);
  });
}
