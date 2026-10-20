import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/data/api/llm_api.dart';
import 'package:memos_go/data/llm/rag_chat_engine.dart';
import 'package:memos_go/data/llm/retrieval.dart';
import 'package:memos_go/data/local/app_database.dart';
import 'package:memos_go/data/local/chat_dao.dart';
import 'package:memos_go/data/local/embedding_dao.dart';
import 'package:memos_go/data/models/models.dart';
import 'package:memos_go/data/repositories/llm_repository.dart';

const _settings = LlmSettings(
    baseUrl: 'https://l/v1', apiKey: 'k', chatModel: 'c', embeddingModel: 'e-m');

class _FakeRepo extends LlmRepository {
  final chatChunks = <String>['你当时倾向', '于方案 B [1]。'];
  final List<Map<String, dynamic>> postedBodies = [];

  @override
  Future<LlmSettings> load() async => _settings;

  @override
  Future<List<List<double>>> embeddings(LlmSettings s,
      {required List<String> inputs}) async => const [[1.0, 0.0]];

  @override
  Stream<String> chatStream(LlmSettings settings,
      {required List<LlmChatMessage> messages, int? maxTokens}) async* {
    postedBodies.add({
      'messages': [for (final m in messages) m.toJson()],
    });
    for (final chunk in chatChunks) {
      yield chunk;
    }
  }
}

Memo _memo(String uid, String content) => Memo(
    name: 'memos/$uid', content: content, createTime: DateTime(2026, 9, 1));

Future<void> _seedCorpus(AppDatabase db) async {
  await db.memoDao.upsertLocalMemo('acc-1', _memo('plan', '方案 B 更稳妥，先试点'));
  await db.memoDao.upsertLocalMemo('acc-1', _memo('noise', '完全无关的内容'));
  await db.embeddingDao.upsertAll('acc-1', 'e-m', [
    EmbeddingWrite(
        uid: 'plan',
        contentHash: 1,
        vector: Float32List.fromList([1.0, 0.0])),
    EmbeddingWrite(
        uid: 'noise',
        contentHash: 1,
        vector: Float32List.fromList([-1.0, 0.0])),
  ]);
}

void main() {
  late AppDatabase db;
  late _FakeRepo repo;
  late RagChatEngine engine;

  setUp(() async {
    db = AppDatabase.forTests(NativeDatabase.memory());
    repo = _FakeRepo();
    await _seedCorpus(db);
    engine = RagChatEngine(
      accountId: 'acc-1',
      db: db,
      repository: repo,
      retrieval: RetrievalService(db: db, repository: repo),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('streams an answer, persists both turns and numbered sources',
      () async {
    final session = await db.chatDao.createSession('acc-1');
    final turn = await engine.send(
        sessionId: session.id, question: '方案怎么想的', language: 'zh');

    expect(turn.sources.single.uid, 'memos/plan');
    expect(turn.sources.single.n, 1);

    final text = await turn.deltas.join();
    expect(text, '你当时倾向于方案 B [1]。');

    final messages = await db.chatDao.lastMessages('acc-1', session.id, 10);
    expect(messages.map((m) => m.role), ['user', 'assistant']);
    expect(messages.last.content, '你当时倾向于方案 B [1]。');
    expect(messages.last.parsedSources.single.uid, 'memos/plan');
  });

  test('prompt carries system + numbered context + windowed history',
      () async {
    final session = await db.chatDao.createSession('acc-1');
    // 5 轮历史（10 条消息）——窗口只带最近 8 条。
    for (var i = 0; i < 5; i++) {
      await db.chatDao.appendMessage('acc-1', session.id,
          role: 'user', content: '历史问题 $i', now: DateTime(2026, 10, 15, i));
      await db.chatDao.appendMessage('acc-1', session.id,
          role: 'assistant',
          content: '历史回答 $i',
          now: DateTime(2026, 10, 15, i, 0, 1));
    }

    await engine.send(
        sessionId: session.id, question: '最新问题', language: 'zh');
    // 等待 assistant 落库（send 返回时流尚未消费）。
    await Future<void>.delayed(Duration.zero);

    final sent = repo.postedBodies.single['messages'] as List;
    expect(sent.first['role'], 'system');
    expect((sent.first['content'] as String), contains('仅基于'));
    // 窗口 = 最近 8 条历史 + 本轮 user，共 1 system + 9。
    expect(sent.length, 10);
    final last = sent.last as Map;
    expect(last['role'], 'user');
    expect((last['content'] as String), contains('[1]'));
    expect((last['content'] as String), contains('最新问题'));
    expect((last['content'] as String), contains('方案 B 更稳妥'));
  });

  test('long memos are clipped to the excerpt budget', () async {
    await db.memoDao.deleteLocalMemo('acc-1', 'plan');
    final long = List.filled(200, '很长的内容').join();
    await db.memoDao
        .upsertLocalMemo('acc-1', _memo('plan', '$long 结尾'));
    await db.embeddingDao.deleteAllForAccount('acc-1');
    await db.embeddingDao.upsertAll('acc-1', 'e-m', [
      EmbeddingWrite(
          uid: 'plan', contentHash: 2, vector: Float32List.fromList([1.0, 0.0])),
    ]);
    final session = await db.chatDao.createSession('acc-1');
    await engine.send(sessionId: session.id, question: '方案', language: 'zh');

    final sent = repo.postedBodies.first['messages'] as List;
    final context = (sent.last as Map)['content'] as String;
    expect(context.contains('很长的内容'), isTrue);
    expect(context.length, lessThan(1000));

    // 问题文本也受 historyClipChars 预算约束（grapheme 安全）。
    final q = List.filled(2000, '问').join();
    await engine.send(sessionId: session.id, question: q, language: 'zh');
    final sent2 = repo.postedBodies.last['messages'] as List;
    final prompt2 = (sent2.last as Map)['content'] as String;
    // 截后问题（1000 字 + …）加上摘要段；不截断时整条 prompt 约 2400 字。
    expect(prompt2.length, lessThan(1500));
    expect(prompt2.endsWith('…\n'), isTrue);
  });

  test('history answers ride back clipped to the per-message budget',
      () async {
    final session = await db.chatDao.createSession('acc-1');
    // 3000 字的上轮回答：窗口（条数）放它进来，per-message 上限把它截短。
    await db.chatDao.appendMessage('acc-1', session.id,
        role: 'assistant',
        content: '巨' * 3000,
        now: DateTime(2026, 10, 15));

    await engine.send(sessionId: session.id, question: '接着聊', language: 'zh');

    final sent = repo.postedBodies.single['messages'] as List;
    expect(sent.length, 3); // system + 1 条被截短的历史 + 本轮 user
    final history = sent[1] as Map;
    expect(history['role'], 'assistant');
    final content = history['content'] as String;
    expect(content.length, lessThanOrEqualTo(1001)); // clip + ellipsis
    expect(content.endsWith('…'), isTrue);
  });

  test('mid-stream failure persists the partial answer with sources',
      () async {
    final failing = RagChatEngine(
      accountId: 'acc-1',
      db: db,
      repository: _PartialThenThrowRepo(),
      retrieval: RetrievalService(db: db, repository: _PartialThenThrowRepo()),
    );
    final session = await db.chatDao.createSession('acc-1');
    final turn =
        await failing.send(sessionId: session.id, question: '方案', language: 'zh');

    // onDone 在 pump 落库与 close 之后触发——await 它即可安全断言持久化结果。
    final errors = <Object>[];
    final done = Completer<void>();
    turn.deltas.listen((_) {}, onError: errors.add, onDone: done.complete);
    await done.future;

    expect(errors.single, isA<LlmApiException>());
    final messages = await db.chatDao.lastMessages('acc-1', session.id, 10);
    expect(messages.map((m) => m.role), ['user', 'assistant']);
    expect(messages.last.content, '部分');
    expect(messages.last.parsedSources.single.uid, 'memos/plan');
  });

  test('failure before the first chunk persists no assistant row', () async {
    final failing = RagChatEngine(
      accountId: 'acc-1',
      db: db,
      repository: _ThrowBeforeFirstChunkRepo(),
      retrieval:
          RetrievalService(db: db, repository: _ThrowBeforeFirstChunkRepo()),
    );
    final session = await db.chatDao.createSession('acc-1');
    final turn =
        await failing.send(sessionId: session.id, question: '方案', language: 'zh');

    await expectLater(turn.deltas.join(), throwsA(isA<LlmApiException>()));

    final messages = await db.chatDao.lastMessages('acc-1', session.id, 10);
    expect(messages.map((m) => m.role), ['user']);
  });

  test('no embedding model still chats, without citations', () async {
    final bare = RagChatEngine(
      accountId: 'acc-1',
      db: db,
      repository: _ChatOnlyRepo(),
      retrieval: RetrievalService(db: db, repository: _ChatOnlyRepo()),
    );
    final session = await db.chatDao.createSession('acc-1');
    final turn = await bare.send(
        sessionId: session.id, question: '你好', language: 'zh');
    expect(turn.sources, isEmpty);
    expect(await turn.deltas.join(), '你当时倾向于方案 B [1]。');
  });

  test('unconfigured chat model throws LlmApiException', () async {
    final bare = RagChatEngine(
      accountId: 'acc-1',
      db: db,
      repository: _NoChatRepo(),
      retrieval: RetrievalService(db: db, repository: _NoChatRepo()),
    );
    final session = await db.chatDao.createSession('acc-1');
    await expectLater(
        bare.send(sessionId: session.id, question: 'x', language: 'zh'),
        throwsA(isA<LlmApiException>()));
  });
}

class _PartialThenThrowRepo extends LlmRepository {
  @override
  Future<LlmSettings> load() async => _settings;

  @override
  Future<List<List<double>>> embeddings(LlmSettings s,
      {required List<String> inputs}) async => const [[1.0, 0.0]];

  @override
  Stream<String> chatStream(LlmSettings settings,
      {required List<LlmChatMessage> messages, int? maxTokens}) async* {
    yield '部分';
    throw const LlmApiException('HTTP 500 boom');
  }
}

class _ThrowBeforeFirstChunkRepo extends LlmRepository {
  @override
  Future<LlmSettings> load() async => _settings;

  @override
  Future<List<List<double>>> embeddings(LlmSettings s,
      {required List<String> inputs}) async => const [[1.0, 0.0]];

  @override
  Stream<String> chatStream(LlmSettings settings,
      {required List<LlmChatMessage> messages, int? maxTokens}) async* {
    throw const LlmApiException('HTTP 500 before first chunk');
  }
}

class _ChatOnlyRepo extends LlmRepository {
  @override
  Future<LlmSettings> load() async => const LlmSettings(
      baseUrl: 'https://l/v1', apiKey: 'k', chatModel: 'c');

  @override
  Stream<String> chatStream(LlmSettings settings,
      {required List<LlmChatMessage> messages, int? maxTokens}) async* {
    yield '你当时倾向于方案 B [1]。';
  }
}

class _NoChatRepo extends LlmRepository {
  @override
  Future<LlmSettings> load() async => const LlmSettings();
}
