import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/core/utils/stable_hash.dart';
import 'package:memos_go/data/api/llm_api.dart';
import 'package:memos_go/data/llm/vectorization_engine.dart';
import 'package:memos_go/data/local/app_database.dart';
import 'package:memos_go/data/local/embedding_dao.dart';
import 'package:memos_go/data/models/models.dart';
import 'package:memos_go/data/repositories/llm_repository.dart';

/// Deterministic embedding endpoint: records batches, returns 2-dim vectors.
class FakeVectorRepository extends LlmRepository {
  FakeVectorRepository(this.settings, {this.failWith});

  final LlmSettings settings;
  final String? failWith;
  final batches = <List<String>>[];

  @override
  Future<LlmSettings> load() async => settings;

  @override
  Future<List<List<double>>> embeddings(LlmSettings s,
      {required List<String> inputs}) async {
    final failure = failWith;
    if (failure != null) throw LlmApiException(failure);
    batches.add(inputs);
    return [for (final text in inputs) [text.length.toDouble(), 1.0]];
  }
}

Memo memo(String uid, String content) => Memo(
    name: 'memos/$uid', content: content, createTime: DateTime(2026, 10, 1));

/// Embeddings stall on [gate] so a test can interleave clearVectors with an
/// in-flight batch.
class GatedVectorRepository extends FakeVectorRepository {
  GatedVectorRepository(super.settings, {required this.gate});

  final Completer<void> gate;

  @override
  Future<List<List<double>>> embeddings(LlmSettings s,
      {required List<String> inputs}) async {
    await gate.future;
    return super.embeddings(s, inputs: inputs);
  }
}

/// load() blows up: run() must absorb it into state, not throw.
class ThrowingLoadRepository extends FakeVectorRepository {
  ThrowingLoadRepository(super.settings);

  @override
  Future<LlmSettings> load() async => throw Exception('keychain exploded');
}

/// load() stalls on [gate] so a test can interleave pause() with run()'s
/// initial awaits.
class _GatedLoadRepository extends FakeVectorRepository {
  _GatedLoadRepository(super.settings);

  final gate = Completer<void>();

  @override
  Future<LlmSettings> load() async {
    await gate.future;
    return settings;
  }
}

const configured = LlmSettings(
  baseUrl: 'https://llm.example.com/v1',
  apiKey: 'sk-x',
  chatModel: 'chat-m',
  embeddingModel: 'e-m',
);

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTests(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<VectorizationEngine> engine(FakeVectorRepository repo) async {
    final e = VectorizationEngine(
        accountId: 'acc-1', db: db, repository: repo);
    await e.run();
    return e;
  }

  test('embeds everything in batches of 16 and ends idle', () async {
    for (var i = 0; i < 20; i++) {
      await db.memoDao.upsertLocalMemo('acc-1', memo('m$i', 'content $i'));
    }
    final repo = FakeVectorRepository(configured);
    final e = await engine(repo);

    expect(repo.batches.map((b) => b.length), [16, 4]);
    final hashes = await db.embeddingDao.embeddedHashes('acc-1', 'e-m');
    expect(hashes.length, 20);
    expect(hashes['m7'], stableHash('content 7'));
    expect(e.state.value.status, VectorStatus.idle);
    expect(e.state.value.embedded, 20);
    expect(e.state.value.total, 20);
  });

  test('skips memos whose content hash already matches', () async {
    await db.memoDao.upsertLocalMemo('acc-1', memo('a', 'same'));
    await db.memoDao.upsertLocalMemo('acc-1', memo('b', 'will change'));
    final repo = FakeVectorRepository(configured);
    await engine(repo);

    repo.batches.clear();
    await db.memoDao
        .upsertLocalMemo('acc-1', memo('b', 'changed content'));
    final e = await engine(repo);

    expect(repo.batches, [
      ['changed content']
    ]);
    expect(e.state.value.embedded, 2);
  });

  test('switching the model re-embeds everything and sweeps the old model',
      () async {
    await db.memoDao.upsertLocalMemo('acc-1', memo('a', 'x'));
    await engine(FakeVectorRepository(configured));

    final repo2 = FakeVectorRepository(
        const LlmSettings(baseUrl: 'https://l/v1', apiKey: 'k',
            chatModel: 'c', embeddingModel: 'e-other'));
    await engine(repo2);

    expect(repo2.batches, [
      ['x']
    ]);
    expect((await db.embeddingDao.vectorsForModel('acc-1', 'e-other')).length,
        1);
    // A completed pass makes the new model the only source of truth.
    expect((await db.embeddingDao.vectorsForModel('acc-1', 'e-m')).length, 0);
  });

  test('unconfigured settings leave the engine idle with no calls',
      () async {
    await db.memoDao.upsertLocalMemo('acc-1', memo('a', 'x'));
    final repo =
        FakeVectorRepository(const LlmSettings(baseUrl: '', apiKey: ''));
    final e = await engine(repo);

    expect(repo.batches, isEmpty);
    expect(e.state.value.status, VectorStatus.idle);
    expect(e.state.value.total, 0);
  });

  test('paused engine performs no calls', () async {
    await db.memoDao.upsertLocalMemo('acc-1', memo('a', 'x'));
    final repo = FakeVectorRepository(configured);
    final e = VectorizationEngine(
        accountId: 'acc-1', db: db, repository: repo);
    e.pause();
    await e.run();
    expect(repo.batches, isEmpty);
    expect(e.state.value.status, VectorStatus.paused);
  });

  test('endpoint failure records an error and stops', () async {
    await db.memoDao.upsertLocalMemo('acc-1', memo('a', 'x'));
    final repo = FakeVectorRepository(configured, failWith: 'HTTP 500 boom');
    final e = await engine(repo);

    expect(e.state.value.status, VectorStatus.error);
    expect(e.state.value.lastError, contains('boom'));
    expect(
        await db.embeddingDao.embeddedHashes('acc-1', 'e-m'), isEmpty);
  });

  test('clearVectors wipes rows and resets state', () async {
    await db.memoDao.upsertLocalMemo('acc-1', memo('a', 'x'));
    final e = await engine(FakeVectorRepository(configured));
    await e.clearVectors();

    expect(await db.embeddingDao.embeddedHashes('acc-1', 'e-m'), isEmpty);
    expect(e.state.value.total, 0);
  });

  test('a completed pass sweeps orphan rows', () async {
    await db.embeddingDao.upsertAll('acc-1', 'e-m', [
      EmbeddingWrite(
          uid: 'ghost', contentHash: 1, vector: Float32List.fromList([1])),
    ]);
    final e = await engine(FakeVectorRepository(configured));
    expect(e.state.value.status, VectorStatus.idle);
    expect(await db.embeddingDao.embeddedHashes('acc-1', 'e-m'), isEmpty);
  });

  test('clearVectors aborts an in-flight pass and leaves it paused',
      () async {
    for (var i = 0; i < 20; i++) {
      await db.memoDao.upsertLocalMemo('acc-1', memo('m$i', 'content $i'));
    }
    final gate = Completer<void>();
    final e = VectorizationEngine(
        accountId: 'acc-1',
        db: db,
        repository: GatedVectorRepository(configured, gate: gate));
    final done = e.run();
    // Let the pass reach the gated embeddings call.
    await Future<void>.delayed(Duration.zero);
    await e.clearVectors();
    gate.complete();
    await done;

    // Nothing resurrected after the wipe, and the engine stays paused
    // until resume().
    expect(await db.embeddingDao.embeddedHashes('acc-1', 'e-m'), isEmpty);
    expect(e.state.value.status, VectorStatus.paused);
  });

  test('load() failure lands in state instead of throwing', () async {
    await db.memoDao.upsertLocalMemo('acc-1', memo('a', 'x'));
    final e = VectorizationEngine(
        accountId: 'acc-1', db: db, repository: ThrowingLoadRepository(
            configured));
    await e.run();

    expect(e.state.value.status, VectorStatus.error);
    expect(e.state.value.lastError, contains('keychain exploded'));
  });

  test('pause landing during initial awaits keeps status paused', () async {
    await db.memoDao.upsertLocalMemo('acc-1', memo('a', 'x'));
    final repo = _GatedLoadRepository(configured);
    final engine = VectorizationEngine(
        accountId: 'acc-1', db: db, repository: repo);
    final done = engine.run();
    await Future<void>.delayed(Duration.zero);
    engine.pause();
    repo.gate.complete();
    await done;

    expect(engine.state.value.status, VectorStatus.paused);
    expect(repo.batches, isEmpty);
  });
}
