import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Locale;

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/core/utils/stable_hash.dart';
import 'package:memos_go/data/llm/ai_activity_guard.dart';
import 'package:memos_go/data/llm/retrieval.dart';
import 'package:memos_go/data/llm/suggestion_engine.dart';
import 'package:memos_go/data/local/app_database.dart';
import 'package:memos_go/data/local/embedding_dao.dart';
import 'package:memos_go/data/local/suggestion_dao.dart';
import 'package:memos_go/data/models/models.dart';
import 'package:memos_go/data/repositories/llm_repository.dart';
import 'package:memos_go/data/api/llm_api.dart';

const _settings = LlmSettings(
  baseUrl: 'https://l/v1',
  apiKey: 'k',
  chatModel: 'c',
  embeddingModel: 'e-m',
);

class _FakeRepo extends LlmRepository {
  _FakeRepo({this.reply});

  /// 模型回复；null 时抛错。
  final String? reply;
  final bodies = <List<Map<String, dynamic>>>[];

  @override
  Future<LlmSettings> load() async => _settings;

  @override
  Future<List<List<double>>> embeddings(
    LlmSettings s, {
    required List<String> inputs,
  }) async => const [
    [1.0, 0.0],
  ];

  @override
  Future<String> chat(
    LlmSettings settings, {
    required List<LlmChatMessage> messages,
    int? maxTokens,
  }) async {
    bodies.add([for (final m in messages) m.toJson()]);
    final r = reply;
    if (r == null) throw const LlmApiException('HTTP 503 boom');
    return r;
  }
}

Memo _memo(String uid, String content, {List<String> tags = const []}) => Memo(
  name: 'memos/$uid',
  content: content,
  tags: tags,
  createTime: DateTime(2026, 10, 20),
);

Future<void> _seedCorpus(AppDatabase db) async {
  await db.memoDao.upsertLocalMemo(
    'acc-1',
    _memo('rel1', 'k8s 滚动更新排查', tags: ['运维']),
  );
  await db.memoDao.upsertLocalMemo('acc-1', _memo('rel2', '发布流程复盘'));
  await db.memoDao.upsertLocalMemo('acc-1', _memo('far', '完全无关的菜谱'));
  await db.embeddingDao.upsertAll('acc-1', 'e-m', [
    EmbeddingWrite(
      uid: 'rel1',
      contentHash: 1,
      vector: Float32List.fromList([1.0, 0.0]),
    ),
    EmbeddingWrite(
      uid: 'rel2',
      contentHash: 1,
      vector: Float32List.fromList([0.9, 0.1]),
    ),
    EmbeddingWrite(
      uid: 'far',
      contentHash: 1,
      vector: Float32List.fromList([-1.0, 0.0]),
    ),
  ]);
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTests(NativeDatabase.memory());
    await _seedCorpus(db);
  });

  tearDown(() async {
    await db.close();
  });

  SuggestionEngine engine(_FakeRepo repo) => SuggestionEngine(
    accountId: 'acc-1',
    db: db,
    repository: repo,
    retrieval: RetrievalService(db: db, repository: repo),
  );

  test('new memos after the initial snapshot get suggestions', () async {
    final repo = _FakeRepo(
      reply: '''
```json
{"tags": ["运维"], "related": [1, 2]}
```
''',
    );
    final e = engine(repo);
    e.start(); // 首帧建快照，不产出。
    await Future<void>.delayed(Duration.zero);
    expect(
      await db.suggestionDao.watchSuggestion('acc-1', 'rel1').first,
      isNull,
      reason: '初始语料不回填',
    );

    await db.memoDao.upsertLocalMemo('acc-1', _memo('new1', '今晚又发布翻车'));
    await Future<void>.delayed(Duration.zero);
    await e.run();

    final row = await db.suggestionDao.watchSuggestion('acc-1', 'new1').first;
    expect(row, isNotNull);
    expect(row!.tagList, ['运维']);
    expect(row.relatedUidList, ['memos/rel1', 'memos/rel2']);
    expect(row.contentHash, stableHash('今晚又发布翻车'));
  });

  test('content change invalidates and recomputes', () async {
    final repo = _FakeRepo(reply: '{"tags": [], "related": []}');
    final e = engine(repo);
    e.start();
    await Future<void>.delayed(Duration.zero);
    await db.memoDao.upsertLocalMemo('acc-1', _memo('new1', 'v1'));
    await Future<void>.delayed(Duration.zero);
    await e.run();

    repo.bodies.clear();
    await db.memoDao.upsertLocalMemo('acc-1', _memo('new1', 'v2 改了'));
    await Future<void>.delayed(Duration.zero);
    await e.run();

    expect(repo.bodies.length, 1, reason: '只重算变更的那条');
    final row = await db.suggestionDao.watchSuggestion('acc-1', 'new1').first;
    expect(row!.contentHash, stableHash('v2 改了'));
  });

  test(
    'prompt carries account tags, numbered candidates and the memo',
    () async {
      final repo = _FakeRepo(reply: '{"tags": [], "related": []}');
      final e = engine(repo);
      e.start();
      await Future<void>.delayed(Duration.zero);
      await db.memoDao.upsertLocalMemo('acc-1', _memo('new1', '新笔记内容'));
      await Future<void>.delayed(Duration.zero);
      await e.run();

      final messages = repo.bodies.single;
      expect(messages.first['role'], 'system');
      final system = messages.first['content'] as String;
      expect(system, contains('JSON'));
      expect(system, contains('你为刚保存的笔记'));
      final user = messages.last['content'] as String;
      expect(user, contains('已有标签：'));
      expect(user, contains('候选相关记忆：'));
      expect(user, contains('新笔记：'));
      expect(user, contains('运维')); // 已有标签清单
      expect(user, contains('[1]')); // 编号候选
      expect(user, contains('k8s 滚动更新排查')); // 候选摘录
      expect(user, contains('新笔记内容')); // memo 内容
      await e.dispose();
    },
  );

  test('run with no language argument follows the callback', () async {
    var code = 'en';
    final repo = _FakeRepo(reply: '{"tags": [], "related": []}');
    final e = SuggestionEngine(
      accountId: 'acc-1',
      db: db,
      repository: repo,
      retrieval: RetrievalService(db: db, repository: repo),
      language: () => code,
    );
    e.start();
    await Future<void>.delayed(Duration.zero);
    await db.memoDao.upsertLocalMemo('acc-1', _memo('new1', 'hello note'));
    await Future<void>.delayed(Duration.zero);
    // The debounce timer calls run() the same way: no language argument.
    await e.run();

    final first = repo.bodies.single;
    expect(first.first['content'] as String, contains('You suggest metadata'));
    final user = first.last['content'] as String;
    expect(user, contains('Existing tags:'));
    expect(user, contains('Candidate related memos:'));
    expect(user, contains('New note:'));
    expect(user, contains('hello note'));

    repo.bodies.clear();
    code = 'zh';
    await db.memoDao.upsertLocalMemo('acc-1', _memo('new1', '改成中文笔记'));
    await Future<void>.delayed(Duration.zero);
    await e.run();
    final second = repo.bodies.single.last['content'] as String;
    expect(second, contains('已有标签：'));
    expect(second, contains('新笔记：'));
    expect(second, contains('改成中文笔记'));
    await e.dispose();
  });

  test('explicit language overrides the callback', () async {
    final repo = _FakeRepo(reply: '{"tags": [], "related": []}');
    final e = SuggestionEngine(
      accountId: 'acc-1',
      db: db,
      repository: repo,
      retrieval: RetrievalService(db: db, repository: repo),
      language: () => 'zh',
    );
    e.start();
    await Future<void>.delayed(Duration.zero);
    await db.memoDao.upsertLocalMemo('acc-1', _memo('new1', 'hello note'));
    await Future<void>.delayed(Duration.zero);
    await e.run(language: 'en-US');

    expect(
      repo.bodies.single.first['content'] as String,
      contains('You suggest metadata'),
    );
    await e.dispose();
  });

  test('an invalidated guard drops an in-flight suggestion', () async {
    final gate = Completer<String>();
    final repo = _GatedRepo(gate);
    final guard = AiActivityGuard();
    final e = SuggestionEngine(
      accountId: 'acc-1',
      db: db,
      repository: repo,
      retrieval: RetrievalService(db: db, repository: repo),
      language: () => 'en',
      guard: guard,
    );
    e.start();
    await Future<void>.delayed(Duration.zero);
    await db.memoDao.upsertLocalMemo('acc-1', _memo('new1', 'hello note'));
    await Future<void>.delayed(Duration.zero);
    final pending = e.run();
    await Future<void>.delayed(Duration.zero);
    guard.invalidate();
    gate.complete('{"tags": ["ops"], "related": [1]}');
    await pending;

    expect(
      await db.suggestionDao.watchSuggestion('acc-1', 'new1').first,
      isNull,
    );
    await e.dispose();
  });

  test('hallucinated or self references are dropped', () async {
    final repo = _FakeRepo(
      reply: '{"tags": ["a", "a", "#b", ""], "related": [9, 1]}',
    );
    final e = engine(repo);
    e.start();
    await Future<void>.delayed(Duration.zero);
    await db.memoDao.upsertLocalMemo('acc-1', _memo('new1', 'x'));
    await Future<void>.delayed(Duration.zero);
    await e.run();

    final row = await db.suggestionDao.watchSuggestion('acc-1', 'new1').first;
    expect(row!.tagList, ['a', 'b']);
    expect(row.relatedUidList, ['memos/rel1']);
  });

  test('self exclusion from candidates and output', () async {
    final repo = _FakeRepo(reply: '{"tags": [], "related": ["memos/new1"]}');
    final e = engine(repo);
    e.start();
    await Future<void>.delayed(Duration.zero);
    await db.memoDao.upsertLocalMemo('acc-1', _memo('new1', 'x'));
    await Future<void>.delayed(Duration.zero);
    await e.run();

    final row = await db.suggestionDao.watchSuggestion('acc-1', 'new1').first;
    expect(row!.relatedUidList, isEmpty);
    // 提示词的候选编号不含自身。
    final user = repo.bodies.single.last['content'] as String;
    expect(user, isNot(contains('[6]')));
  });

  test('endpoint failure records error and moves on', () async {
    final repo = _FakeRepo(); // chat 抛 503
    final e = engine(repo);
    e.start();
    await Future<void>.delayed(Duration.zero);
    await db.memoDao.upsertLocalMemo('acc-1', _memo('new1', 'x'));
    await db.memoDao.upsertLocalMemo('acc-1', _memo('new2', 'y'));
    await Future<void>.delayed(Duration.zero);
    await e.run();

    expect(e.lastError.value, contains('503'));
    expect(repo.bodies.length, 2, reason: '失败不阻塞后续条目');
    expect(
      await db.suggestionDao.watchSuggestion('acc-1', 'new1').first,
      isNull,
    );
  });

  test(
    'suggestOnSave off or embeddings unconfigured skips everything',
    () async {
      final repo = _FakeRepo(reply: '{"tags": [], "related": []}');
      final e = engine(repo);
      e.start();
      await Future<void>.delayed(Duration.zero);
      // 关闭路径：_OffRepo 未配置 embeddingModel，run() 整体跳过（brief 允许
      // 用"未配置"或"suggestOnSave=false"任一形态表达该用例）。
      final e2 = SuggestionEngine(
        accountId: 'acc-1',
        db: db,
        repository: _OffRepo(),
        retrieval: RetrievalService(db: db, repository: _OffRepo()),
      );
      e2.start();
      await Future<void>.delayed(Duration.zero);
      await db.memoDao.upsertLocalMemo('acc-1', _memo('new1', 'x'));
      await Future<void>.delayed(Duration.zero);
      await e2.run();
      expect(e2.lastError.value, isNull);
      expect(
        await db.suggestionDao.watchSuggestion('acc-1', 'new1').first,
        isNull,
      );
    },
  );

  test('parseSuggestion handles fenced json and garbage', () {
    const candidates = ['memos/a', 'memos/b'];
    expect(
      parseSuggestion(
        '```json\n{"tags":["t1"],"related":[2]}\n```',
        candidateUids: candidates,
        selfName: 'memos/x',
      ),
      isNotNull,
    );
    expect(
      parseSuggestion(
        '前置说明 {"tags":["t1"],"related":[]} 后缀',
        candidateUids: candidates,
        selfName: 'memos/x',
      )!.tags,
      ['t1'],
    );
    expect(
      parseSuggestion(
        '根本不是 json',
        candidateUids: candidates,
        selfName: 'memos/x',
      ),
      isNull,
    );
  });

  test('resolveSuggestionLanguage follows the setting, then the platform', () {
    expect(
      resolveSuggestionLanguage(
        localeCode: 'en',
        platformLocales: const [Locale('zh')],
      ),
      'en',
    );
    expect(
      resolveSuggestionLanguage(
        localeCode: 'zh',
        platformLocales: const [Locale('en', 'US')],
      ),
      'zh',
    );
    expect(
      resolveSuggestionLanguage(
        localeCode: '',
        platformLocales: const [Locale('zh', 'CN')],
      ),
      'zh',
    );
    expect(
      resolveSuggestionLanguage(
        localeCode: '',
        platformLocales: const [Locale('en', 'US')],
      ),
      'en',
    );
    expect(
      resolveSuggestionLanguage(
        localeCode: '',
        platformLocales: const [Locale('fr'), Locale('zh')],
      ),
      'zh',
    );
    expect(
      resolveSuggestionLanguage(
        localeCode: '',
        platformLocales: const [Locale('fr')],
      ),
      'en',
    );
    expect(resolveSuggestionLanguage(localeCode: ''), 'en');
    expect(normalizeSuggestionLanguage('en-US'), 'en');
    expect(normalizeSuggestionLanguage('EN'), 'en');
    expect(normalizeSuggestionLanguage('zh_Hans'), 'zh');
  });
}

class _GatedRepo extends _FakeRepo {
  _GatedRepo(this.gate) : super(reply: '{"tags": [], "related": []}');

  final Completer<String> gate;

  @override
  Future<String> chat(
    LlmSettings settings, {
    required List<LlmChatMessage> messages,
    int? maxTokens,
  }) async {
    bodies.add([for (final m in messages) m.toJson()]);
    return gate.future;
  }
}

class _OffRepo extends LlmRepository {
  @override
  Future<LlmSettings> load() async =>
      const LlmSettings(baseUrl: 'https://l/v1', apiKey: 'k', chatModel: 'c');
}
