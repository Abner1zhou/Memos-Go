import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/app.dart';
import 'package:memos_go/data/models/models.dart';
import 'package:memos_go/data/repositories/auth_repository.dart';
import 'package:memos_go/data/repositories/memo_repository.dart';
import 'package:memos_go/providers/auth_providers.dart';
import 'package:memos_go/providers/sync_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_secure_storage.dart';

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
    // Empty secure storage, explicitly mocked: the voice flow now waits
    // for the provider's async hydration, which never settles against an
    // unmocked platform channel.
    FlutterSecureStoragePlatform.instance = FakeSecureStorage();
    addTearDown(() => FlutterSecureStoragePlatform.instance =
        MethodChannelFlutterSecureStorage());

    await pumpHome(tester);

    await tester.longPress(find.byIcon(Icons.add));
    await tester.pump();
    await tester.pump();

    expect(find.text('Speech recognition not configured'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'long-press on the + FAB uses the stored ASR config on a cold start',
      (tester) async {
    // Regression: the provider hydrates from storage asynchronously, and a
    // one-shot read at the entry point used to see the optimistic defaults
    // even though storage held a valid config — false "not configured".
    FlutterSecureStoragePlatform.instance = FakeSecureStorage()
      ..values['memos_go.asrConfig'] =
          '{"dialect":"openai","baseUrl":"https://x/v1","apiKey":"k",'
          '"model":"m","language":"","keepAudio":true}';
    addTearDown(() => FlutterSecureStoragePlatform.instance =
        MethodChannelFlutterSecureStorage());
    // Deny mic permission so the flow stops right after the config check
    // instead of opening a recording sheet.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (call) async => false,
    );

    await pumpHome(tester);
    await tester.longPress(find.byIcon(Icons.add));
    await tester.pump();
    await tester.pump();

    expect(find.text('Speech recognition not configured'), findsNothing);
    expect(find.text('Microphone permission not granted'), findsOneWidget);
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
