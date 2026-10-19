import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:memos_go/data/api/llm_api.dart';
import 'package:memos_go/data/llm/rag_chat_engine.dart';
import 'package:memos_go/data/llm/retrieval.dart';
import 'package:memos_go/data/local/app_database.dart';
import 'package:memos_go/data/local/embedding_dao.dart';
import 'package:memos_go/data/models/models.dart';
import 'package:memos_go/data/repositories/llm_repository.dart';
import 'package:memos_go/features/chat/chat_page.dart';
import 'package:memos_go/l10n/generated/app_localizations.dart';
import 'package:memos_go/providers/auth_providers.dart';
import 'package:memos_go/providers/llm_providers.dart';
import 'package:memos_go/providers/rag_chat_providers.dart';
import 'package:memos_go/providers/retrieval_providers.dart';
import 'package:memos_go/providers/sync_providers.dart';
import 'package:memos_go/providers/vectorization_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_secure_storage.dart';
import 'helpers/offline_app.dart';

/// Transport fakes only: `load` is inherited so hydration reads the
/// [FakeSecureStorage] platform instance, letting each test choose the
/// configured/unconfigured state via `storage.values`.
class _FakeRepo extends LlmRepository {
  @override
  Future<List<List<double>>> embeddings(LlmSettings s,
      {required List<String> inputs}) async => const [[1.0, 0.0]];

  @override
  Stream<String> chatStream(LlmSettings settings,
      {required List<LlmChatMessage> messages, int? maxTokens}) async* {
    yield '你倾向于方案 B [1]。';
  }
}

class _StubAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
        status: AuthStatus.signedIn,
        accounts: [testAccount],
        activeAccount: testAccount,
      );
}

Memo _memo(String uid, String content) => Memo(
    name: 'memos/$uid', content: content, createTime: DateTime(2026, 9, 1));

void main() {
  late FakeSecureStorage storage;
  late AppDatabase db;

  setUp(() async {
    storage = FakeSecureStorage();
    FlutterSecureStoragePlatform.instance = storage;
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTests(NativeDatabase.memory());
    await db.memoDao.upsertLocalMemo(
        testAccount.id, _memo('plan', '方案 B 更稳妥'));
    await db.embeddingDao.upsertAll(testAccount.id, 'e-m', [
      EmbeddingWrite(
          uid: 'plan',
          contentHash: 1,
          vector: Float32List.fromList([1.0, 0.0])),
    ]);
    storage.values['memos_go.llmConfig'] =
        '{"baseUrl":"https://l/v1","apiKey":"k","chatModel":"c","embeddingModel":"e-m"}';
  });

  tearDown(() async {
    FlutterSecureStoragePlatform.instance =
        MethodChannelFlutterSecureStorage();
    await db.close();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/chat',
      routes: [
        GoRoute(
          path: '/chat',
          builder: (context, state) => const ChatPage(),
        ),
        GoRoute(
          path: '/memos/detail/:uid',
          builder: (context, state) =>
              Scaffold(body: Text('detail:${state.pathParameters['uid']}')),
        ),
        GoRoute(
          path: '/settings/llm',
          builder: (context, state) => const Scaffold(body: Text('llm-settings')),
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
        llmRepositoryProvider.overrideWith((ref) => _FakeRepo()),
        retrievalServiceProvider.overrideWith(
            (ref) => RetrievalService(db: db, repository: _FakeRepo())),
        ragChatEngineProvider.overrideWith((ref) => RagChatEngine(
            accountId: testAccount.id,
            db: db,
            repository: _FakeRepo(),
            retrieval: RetrievalService(db: db, repository: _FakeRepo()))),
      ],
      child: MaterialApp.router(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('streams an answer with citations and persists the session',
      (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), '方案怎么想');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    // topKSimilar scores on a background isolate (Isolate.run): the result
    // only arrives as a real event-loop message, which fake async never
    // services. Yield to the real loop so the isolate result lands, then
    // flush the fake-async microtask chain (same as search_page_test).
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();

    expect(find.textContaining('方案 B'), findsWidgets);
    expect(find.text('[1]'), findsWidgets);
    // 引用 chip 存在并可点（此处只断言存在）。
    expect(find.textContaining('方案 B 更稳妥'), findsWidgets);

    final sessions =
        await tester.runAsync(() => db.chatDao.watchSessions(testAccount.id).first);
    expect(sessions, isNotEmpty);
    final messages = await tester
        .runAsync(() => db.chatDao.lastMessages(testAccount.id, sessions!.first.id, 10));
    expect(messages!.map((m) => m.role), ['user', 'assistant']);
  });

  testWidgets('unconfigured shows the setup affordance', (tester) async {
    storage.values.remove('memos_go.llmConfig');
    await pumpPage(tester);

    expect(find.text('先配置 AI 助手（对话模型），即可与记忆对话'), findsOneWidget);
    expect(find.text('去配置'), findsOneWidget);
  });
}
