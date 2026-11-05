import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/data/llm/ai_activity_guard.dart';
import 'package:memos_go/data/llm/ai_privacy.dart';
import 'package:memos_go/data/llm/vectorization_engine.dart';
import 'package:memos_go/data/local/app_database.dart';
import 'package:memos_go/data/local/embedding_dao.dart';
import 'package:memos_go/data/local/suggestion_dao.dart';
import 'package:memos_go/data/models/models.dart';
import 'package:memos_go/data/repositories/llm_repository.dart';
import 'package:memos_go/features/review/review_digest.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _settings = LlmSettings(
  baseUrl: 'https://l/v1',
  apiKey: 'k',
  chatModel: 'c',
  embeddingModel: 'e-m',
);

Memo _memo(String uid, String content) => Memo(
  name: 'memos/$uid',
  content: content,
  createTime: DateTime(2026, 10, 1),
);

Future<void> _wipe(
  AppDatabase db, {
  VectorizationEngine? vectorization,
  AiActivityGuard? guard,
}) => wipeLocalAiArtifacts(
  db: db,
  vectorization: vectorization,
  guard: guard,
  clearDigests: ReviewDigestCache().clearAll,
);

void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({'settings.themeMode': 'dark'});
    db = AppDatabase.forTests(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('wipe removes AI artifacts for every account and keeps memos', () async {
    await db.memoDao.upsertLocalMemo('acc-1', _memo('a', 'note a'));
    await db.memoDao.upsertLocalMemo('acc-2', _memo('b', 'note b'));
    await db.embeddingDao.upsertAll('acc-1', 'e-m', [
      EmbeddingWrite(
        uid: 'a',
        contentHash: 1,
        vector: Float32List.fromList([1, 0]),
      ),
    ]);
    await db.embeddingDao.upsertAll('acc-2', 'other', [
      EmbeddingWrite(
        uid: 'b',
        contentHash: 2,
        vector: Float32List.fromList([0, 1]),
      ),
    ]);
    final s1 = await db.chatDao.createSession('acc-1');
    await db.chatDao.appendMessage(
      'acc-1',
      s1.id,
      role: 'user',
      content: 'hi',
      now: DateTime(2026, 10, 2),
    );
    final s2 = await db.chatDao.createSession('acc-2');
    await db.chatDao.appendMessage(
      'acc-2',
      s2.id,
      role: 'assistant',
      content: 'hello',
      now: DateTime(2026, 10, 2),
    );
    const suggestion = MemoSuggestion(tags: ['t'], relatedUids: ['memos/a']);
    await db.suggestionDao.upsert(
      'acc-1',
      'a',
      contentHash: 1,
      suggestion: suggestion,
      now: DateTime(2026, 10, 2),
    );
    await db.suggestionDao.upsert(
      'acc-2',
      'b',
      contentHash: 2,
      suggestion: suggestion,
      now: DateTime(2026, 10, 2),
    );
    final entry = ReviewDigestEntry(
      content: 'summary',
      fingerprint: 'fp',
      generatedAt: DateTime(2026, 10, 2),
    );
    await ReviewDigestCache().save('acc-1', '2026-10-02', entry);
    await ReviewDigestCache().save('acc-2', '2026-10-02', entry);

    await _wipe(db);

    expect(await db.embeddingDao.embeddedHashes('acc-1', 'e-m'), isEmpty);
    expect(await db.embeddingDao.embeddedHashes('acc-2', 'other'), isEmpty);
    expect(await db.chatDao.watchSessions('acc-1').first, isEmpty);
    expect(await db.chatDao.watchSessions('acc-2').first, isEmpty);
    expect(await db.chatDao.lastMessages('acc-1', s1.id, 10), isEmpty);
    expect(await db.suggestionDao.watchSuggestion('acc-1', 'a').first, isNull);
    expect(await db.suggestionDao.watchSuggestion('acc-2', 'b').first, isNull);
    expect(await ReviewDigestCache().load('acc-1', '2026-10-02'), isNull);
    expect(await ReviewDigestCache().load('acc-2', '2026-10-02'), isNull);
    expect(await db.memoDao.getMemo('acc-1', 'a'), isNotNull);
    expect(await db.memoDao.getMemo('acc-2', 'b'), isNotNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings.themeMode'), 'dark');
  });

  test(
    'wipe stops an in-flight embedding pass from writing vectors back',
    () async {
      await db.memoDao.upsertLocalMemo('acc-1', _memo('a', 'note a'));
      await db.embeddingDao.upsertAll('acc-2', 'e-m', [
        EmbeddingWrite(
          uid: 'b',
          contentHash: 1,
          vector: Float32List.fromList([1, 0]),
        ),
      ]);
      final gate = Completer<void>();
      final engine = VectorizationEngine(
        accountId: 'acc-1',
        db: db,
        repository: _GatedRepo(gate),
      );
      final done = engine.run();
      await Future<void>.delayed(Duration.zero);

      final guard = AiActivityGuard();
      await _wipe(db, vectorization: engine, guard: guard);
      expect(guard.epoch, 1);
      gate.complete();
      await done;

      expect(await db.embeddingDao.embeddedHashes('acc-1', 'e-m'), isEmpty);
      expect(await db.embeddingDao.embeddedHashes('acc-2', 'e-m'), isEmpty);
      expect(engine.state.value.status, VectorStatus.idle);
    },
  );
}

class _GatedRepo extends LlmRepository {
  _GatedRepo(this.gate);

  final Completer<void> gate;

  @override
  Future<LlmSettings> load() async => _settings;

  @override
  Future<List<List<double>>> embeddings(
    LlmSettings s, {
    required List<String> inputs,
  }) async {
    await gate.future;
    return [
      for (final _ in inputs) const [1.0, 0.0],
    ];
  }
}
