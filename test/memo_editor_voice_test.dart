import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/data/models/models.dart';
import 'package:memos_go/data/repositories/auth_repository.dart';
import 'package:memos_go/data/repositories/memo_repository.dart';
import 'package:memos_go/features/memo_editor/memo_editor_page.dart';
import 'package:memos_go/l10n/generated/app_localizations.dart';
import 'package:memos_go/providers/auth_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_secure_storage.dart';

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
  Future<Memo> getMemo(String uid) async =>
      const Memo(name: 'memos/x', content: '');

  @override
  Future<Memo> updateMemo(Memo memo) async => memo;

  @override
  Future<void> deleteMemo(String uid) async {}

  @override
  Future<UserStats> userStats() async => const UserStats(tagCounts: {});
}

void main() {
  testWidgets('mic button shows setup dialog when ASR is not configured',
      (tester) async {
    // Empty secure storage, explicitly mocked: the voice flow now waits
    // for the provider's async hydration, which never settles against an
    // unmocked platform channel.
    FlutterSecureStoragePlatform.instance = FakeSecureStorage();
    addTearDown(() => FlutterSecureStoragePlatform.instance =
        MethodChannelFlutterSecureStorage());

    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        memoRepositoryProvider.overrideWith((ref) => _FakeMemoRepository()),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MemoEditorPage(),
      ),
    ));
    await tester.pump();

    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump();
    await tester.pump();

    expect(find.text('未配置语音识别'), findsOneWidget);
    expect(find.text('去设置'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
  });

  // Regression: the provider hydrates from storage asynchronously, and a
  // one-shot read at the entry point used to see the optimistic defaults
  // even though storage held a valid config — false "not configured".
  testWidgets('mic button uses the stored ASR config on a cold start',
      (tester) async {
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

    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        memoRepositoryProvider.overrideWith((ref) => _FakeMemoRepository()),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MemoEditorPage(),
      ),
    ));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump();
    await tester.pump();

    expect(find.text('未配置语音识别'), findsNothing);
    expect(find.text('未授予麦克风权限'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Regression: a never-focused TextField has an invalid (-1) selection.
  // Voice input inserts the transcript without the field ever being
  // focused, which used to silently drop the text.
  testWidgets('insert works before the editor field was ever focused',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        memoRepositoryProvider.overrideWith((ref) => _FakeMemoRepository()),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MemoEditorPage(),
      ),
    ));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller, isNotNull);
    expect(field.controller!.selection.isValid, isFalse);

    await tester.tap(find.byIcon(Icons.format_bold_rounded));
    await tester.pump();

    expect(field.controller!.text, '****');
    expect(field.controller!.selection.isValid, isTrue);
  });
}
