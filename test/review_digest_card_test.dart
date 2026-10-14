import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/data/api/llm_api.dart';
import 'package:memos_go/data/models/models.dart';
import 'package:memos_go/data/repositories/llm_repository.dart';
import 'package:memos_go/features/review/review_digest.dart';
import 'package:memos_go/features/review/review_digest_card.dart';
import 'package:memos_go/l10n/generated/app_localizations.dart';
import 'package:memos_go/providers/llm_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_secure_storage.dart';

/// Stands in for [LlmRepository] so no network is touched; records prompts.
class FakeLlmRepository extends LlmRepository {
  FakeLlmRepository(this.stub);

  final String stub;
  final calls = <List<LlmChatMessage>>[];
  String? failWith;

  @override
  Future<String> chat(
    LlmSettings settings, {
    required List<LlmChatMessage> messages,
    int? maxTokens,
  }) async {
    calls.add(messages);
    final failure = failWith;
    if (failure != null) throw LlmApiException(failure);
    return stub;
  }
}

Memo _memo(String name, String content, DateTime created) => Memo(
      name: name,
      content: content,
      createTime: created,
      updateTime: created,
    );

Future<void> pumpCard(
  WidgetTester tester, {
  required FakeLlmRepository repo,
  required List<Memo> today,
  Map<int, List<Memo>> onThisDay = const {},
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        llmRepositoryProvider.overrideWith((ref) => repo),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListView(
            children: [
              ReviewDigestCard(today: today, onThisDay: onThisDay),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  late FakeSecureStorage storage;

  setUp(() {
    storage = FakeSecureStorage();
    FlutterSecureStoragePlatform.instance = storage;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    FlutterSecureStoragePlatform.instance =
        MethodChannelFlutterSecureStorage();
  });

  testWidgets('unconfigured shows a setup affordance, not an error',
      (tester) async {
    await pumpCard(
      tester,
      repo: FakeLlmRepository('unused'),
      today: [_memo('memos/a', '今天写了点东西', DateTime(2026, 10, 14, 9))],
    );

    expect(find.text('AI 摘要'), findsOneWidget);
    expect(find.text('配置大模型接口后，可生成今日摘要与记忆呼应'), findsOneWidget);
    expect(find.text('配置 AI 助手'), findsOneWidget);
  });

  testWidgets('generates on tap, renders markdown and caches the digest',
      (tester) async {
    storage.values['memos_go.llmConfig'] =
        '{"baseUrl":"https://llm.example.com/v1","apiKey":"sk-x",'
        '"chatModel":"deepseek-chat","embeddingModel":""}';
    final repo = FakeLlmRepository('## 今日要点\n- 完成了 LLM 接入');
    final today = [_memo('memos/a', '今天接入了 LLM', DateTime(2026, 10, 14, 9))];

    await pumpCard(tester, repo: repo, today: today);
    expect(find.text('生成 AI 摘要'), findsOneWidget);

    await tester.tap(find.text('生成 AI 摘要'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('完成了 LLM 接入'), findsOneWidget);
    expect(find.text('重新生成'), findsOneWidget);
    // One chat call with a system + a user message.
    expect(repo.calls, hasLength(1));
    expect(repo.calls.single, hasLength(2));
    expect(repo.calls.single.first.role, 'system');
    expect(repo.calls.single.last.content, contains('今天接入了 LLM'));

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith('memos_go.reviewDigest.'));
    expect(keys, isNotEmpty);
  });

  testWidgets('matching cache renders without calling the LLM',
      (tester) async {
    storage.values['memos_go.llmConfig'] =
        '{"baseUrl":"https://llm.example.com/v1","apiKey":"sk-x",'
        '"chatModel":"deepseek-chat","embeddingModel":""}';
    final created = DateTime(2026, 10, 14, 9);
    final today = [_memo('memos/a', '缓存命中测试', created)];
    final fp = ReviewDigestInput(today: today, onThisDay: const {}).fingerprint();
    SharedPreferences.setMockInitialValues({
      'memos_go.reviewDigest.2026-10-14':
          '{"content":"## 今日要点\\n- 来自缓存","fingerprint":"$fp",'
          '"generatedAt":"2026-10-14T21:00:00.000"}',
    });
    final repo = FakeLlmRepository('unused');

    await pumpCard(tester, repo: repo, today: today);

    expect(find.text('来自缓存'), findsOneWidget);
    expect(repo.calls, isEmpty);
  });

  testWidgets('chat failure shows a retry affordance', (tester) async {
    storage.values['memos_go.llmConfig'] =
        '{"baseUrl":"https://llm.example.com/v1","apiKey":"sk-x",'
        '"chatModel":"deepseek-chat","embeddingModel":""}';
    final repo = FakeLlmRepository('unused')..failWith = 'HTTP 500 boom';

    await pumpCard(
        tester, repo: repo, today: [_memo('memos/a', 'x', DateTime(2026, 10, 14, 9))]);
    await tester.tap(find.text('生成 AI 摘要'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('生成失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('nothing to summarize renders no visible card content',
      (tester) async {
    await pumpCard(tester, repo: FakeLlmRepository('unused'), today: const []);
    // The widget stays in the tree (rendering a shrink box); only its
    // visible affordances must be gone.
    expect(find.text('AI 摘要'), findsNothing);
    expect(find.text('生成 AI 摘要'), findsNothing);
  });
}
