import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:memos_go/core/utils/stable_hash.dart';
import 'package:memos_go/data/local/app_database.dart';
import 'package:memos_go/data/local/suggestion_dao.dart';
import 'package:memos_go/data/models/models.dart';
import 'package:memos_go/features/memo_detail/memo_suggestion_section.dart';
import 'package:memos_go/l10n/generated/app_localizations.dart';
import 'package:memos_go/providers/auth_providers.dart';
import 'package:memos_go/providers/suggestion_providers.dart';
import 'package:memos_go/providers/sync_providers.dart';
import 'package:memos_go/providers/vectorization_providers.dart';

import 'fake_secure_storage.dart';
import 'helpers/offline_app.dart';

class _StubAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
        status: AuthStatus.signedIn,
        accounts: [testAccount],
        activeAccount: testAccount,
      );
}

void main() {
  late AppDatabase db;
  late FakeSecureStorage storage;

  setUp(() async {
    // The section is gated on configured LLM settings; without the storage
    // mock the real platform channel never resolves in widget tests and the
    // gate would stay closed forever.
    storage = FakeSecureStorage();
    FlutterSecureStoragePlatform.instance = storage;
    storage.values['memos_go.llmConfig'] =
        '{"baseUrl":"https://llm.example.com/v1","apiKey":"sk-x",'
        '"chatModel":"deepseek-chat","embeddingModel":"text-embedding-v3"}';
    db = AppDatabase.forTests(NativeDatabase.memory());
    await db.memoDao.upsertLocalMemo(testAccount.id, Memo(
        name: 'memos/target',
        content: '目标笔记',
        tags: const [],
        createTime: DateTime(2026, 10, 20)));
    await db.memoDao.upsertLocalMemo(testAccount.id, Memo(
        name: 'memos/rel',
        content: '相关排查记录',
        createTime: DateTime(2026, 9, 1)));
  });

  tearDown(() async {
    FlutterSecureStoragePlatform.instance = MethodChannelFlutterSecureStorage();
    await db.close();
  });

  Future<void> pumpSection(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/detail/target',
      routes: [
        GoRoute(
          path: '/detail/:uid',
          builder: (context, state) => Scaffold(
            body: MemoSuggestionSection(
                memo: Memo(
                    name: 'memos/${state.pathParameters['uid']}',
                    content: '目标笔记',
                    createTime: DateTime(2026, 10, 20))),
          ),
        ),
        GoRoute(
          path: '/memos/detail/:uid',
          builder: (context, state) =>
              Scaffold(body: Text('detail:${state.pathParameters['uid']}')),
        ),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith(_StubAuthNotifier.new),
        memoRepositoryProvider.overrideWith((ref) => offlineRepo(db)),
        appDatabaseProvider.overrideWithValue(db),
        syncEngineProvider.overrideWithValue(null),
        vectorizationEngineProvider.overrideWithValue(null),
        suggestionEngineProvider.overrideWithValue(null),
      ],
      child: MaterialApp.router(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ));
    await tester.pump();
    // Settle the hydrated LLM settings and the drift stream emissions (the
    // first build runs on optimistic defaults, streams land a hop later).
    await tester.pumpAndSettle();
  }

  testWidgets('renders tag chips and related cards; tapping a tag appends it',
      (tester) async {
    await db.suggestionDao.upsert(testAccount.id, 'target',
        contentHash: stableHash('目标笔记'),
        suggestion: const MemoSuggestion(
            tags: ['运维'], relatedUids: ['memos/rel']),
        now: DateTime(2026, 10, 20));
    await pumpSection(tester);

    expect(find.text('AI 建议'), findsOneWidget);
    expect(find.text('#运维'), findsOneWidget);
    expect(find.textContaining('相关排查记录'), findsOneWidget);

    await tester.tap(find.text('#运维'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // offlineRepo 的 updateMemo 走离线降级：本地行已更新。
    final updated = await db.memoDao.getMemo(testAccount.id, 'target');
    expect(updated!.memo.content, contains('#运维'));
  });

  testWidgets('empty or missing suggestion renders nothing', (tester) async {
    await pumpSection(tester);
    expect(find.text('AI 建议'), findsNothing);
  });
}
