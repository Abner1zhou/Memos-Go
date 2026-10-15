import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/core/utils/vector_math.dart';
import 'package:memos_go/data/llm/retrieval.dart';
import 'package:memos_go/data/local/app_database.dart';
import 'package:memos_go/data/local/embedding_dao.dart';
import 'package:memos_go/data/models/models.dart';
import 'package:memos_go/data/repositories/llm_repository.dart';

const _settings = LlmSettings(
    baseUrl: 'https://l/v1', apiKey: 'k', chatModel: 'c', embeddingModel: 'e-m');

class _CountingRepo extends LlmRepository {
  int embeddingCalls = 0;

  @override
  Future<LlmSettings> load() async => _settings;

  @override
  Future<List<List<double>>> embeddings(LlmSettings s,
      {required List<String> inputs}) async {
    embeddingCalls++;
    return const [[1.0, 0.0]]; // 查询向量恒指向正东
  }
}

Memo _memo(String uid, String content) => Memo(
    name: 'memos/$uid', content: content, createTime: DateTime(2026, 10, 1));

void main() {
  late AppDatabase db;
  late _CountingRepo repo;
  late RetrievalService service;

  setUp(() async {
    db = AppDatabase.forTests(NativeDatabase.memory());
    repo = _CountingRepo();
    service = RetrievalService(db: db, repository: repo);
    await db.memoDao.upsertLocalMemo('acc-1', _memo('near', '方向相关'));
    await db.memoDao.upsertLocalMemo('acc-1', _memo('far', '完全不相关'));
    await db.embeddingDao.upsertAll('acc-1', 'e-m', [
      EmbeddingWrite(
          uid: 'near',
          contentHash: 1,
          vector: Float32List.fromList([0.95, 0.05])),
      EmbeddingWrite(
          uid: 'far',
          contentHash: 1,
          vector: Float32List.fromList([-1.0, 0.0])),
    ]);
  });

  tearDown(() async {
    await db.close();
  });

  test('retrieves above-threshold hits with scores', () async {
    final hits = await service.retrieve('acc-1', '方向');
    expect(hits.map((h) => h.record.memo.uid), ['near']);
    expect(hits.single.score, closeTo(
        cosineSimilarity(Float32List.fromList([1, 0]), Float32List.fromList([0.95, 0.05])),
        1e-6));
  });

  test('repeated queries reuse the cached embedding', () async {
    await service.retrieve('acc-1', '方向');
    await service.retrieve('acc-1', '方向');
    expect(repo.embeddingCalls, 1);
    // Different query string re-bills.
    await service.retrieve('acc-1', '另一个问题');
    expect(repo.embeddingCalls, 2);
  });

  test('unconfigured embedding model yields no hits without calls', () async {
    final idle = RetrievalService(
        db: db, repository: _EmptyRepo());
    expect(await idle.retrieve('acc-1', '方向'), isEmpty);
  });

  test('no vectors yields no hits', () async {
    await db.embeddingDao.deleteAllForAccount('acc-1');
    expect(await service.retrieve('acc-1', '方向'), isEmpty);
  });
}

class _EmptyRepo extends LlmRepository {
  @override
  Future<LlmSettings> load() async => const LlmSettings();
}
