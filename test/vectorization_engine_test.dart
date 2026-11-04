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
    batches.add(inputs);
    final failure = failWith;
    if (failure != null) throw LlmApiException(failure);
    return [for (final text in inputs) [text.length.toDouble(), 1.0]];
  }
}

/// Batch calls fail so the engine isolates memos; [bad] then fails alone.
class _OneBadMemoRepository extends FakeVectorRepository {
  _OneBadMemoRepository(super.settings);

  static const bad = 'bad memo';

  @override
  Future<List<List<double>>> embeddings(LlmSettings s,
      {required List<String> inputs}) async {
    batches.add(inputs);
    if (inputs.length > 1 || inputs.single == bad) {
      throw LlmApiException(
          inputs.length > 1 ? 'batch rejected' : 'rejected bad memo');
    }
    return [for (final text in inputs) [text.length.toDouble(), 1.0]];
  }
}

/// Fails every call with an error that should stop the pass immediately.
class _SystemicFailureRepository extends FakeVectorRepository {
  _SystemicFailureRepository(super.settings, this.error);

  final LlmApiException error;

  @override
  Future<List<List<double>>> embeddings(LlmSettings s,
      {required List<String> inputs}) async {
    batches.add(inputs);
    throw error;
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

  test('clips oversized memo text and skips blank input', () async {
    final long = '字' * (VectorizationEngine.maxInputChars + 25);
    await db.memoDao.upsertLocalMemo('acc-1', memo('long', long));
    await db.memoDao.upsertLocalMemo('acc-1', memo('blank', ' \n\t '));
    await db.memoDao.upsertLocalMemo('acc-1', memo('ok', '  hello '));
    await db.embeddingDao.upsertAll('acc-1', 'e-m', [
      EmbeddingWrite(
          uid: 'blank', contentHash: 1, vector: Float32List.fromList([1])),
    ]);
    final repo = FakeVectorRepository(configured);
    final e = await engine(repo);

    final sent = [for (final batch in repo.batches) ...batch];
    expect(sent, hasLength(2));
    expect(sent, contains('hello'));
    expect(sent, contains('字' * VectorizationEngine.maxInputChars));
    expect(sent, isNot(contains(long)));
    final hashes = await db.embeddingDao.embeddedHashes('acc-1', 'e-m');
    expect(hashes['long'], stableHash(long));
    expect(hashes['ok'], stableHash('  hello '));
    expect(hashes.containsKey('blank'), isFalse);
    expect(e.state.value.status, VectorStatus.idle);
    expect(e.state.value.embedded, 2);
    expect(e.state.value.total, 2);
  });

  test('embeddingInput clips on grapheme boundaries', () {
    expect(VectorizationEngine.embeddingInput('  \n\t'), isNull);
    expect(VectorizationEngine.embeddingInput('  hello '), 'hello');
    final emoji = '😀';
    final clipped = VectorizationEngine.embeddingInput(
        emoji * (VectorizationEngine.maxInputChars + 1));
    expect(clipped, emoji * VectorizationEngine.maxInputChars);
  });

  test('one memo failing does not abort the rest of the pass', () async {
    for (var i = 0; i < 16; i++) {
      await db.memoDao.upsertLocalMemo('acc-1', memo('m$i', 'content $i'));
    }
    await db.memoDao
        .upsertLocalMemo('acc-1', memo('bad', _OneBadMemoRepository.bad));
    final repo = _OneBadMemoRepository(configured);
    final e = await engine(repo);

    final hashes = await db.embeddingDao.embeddedHashes('acc-1', 'e-m');
    expect(hashes.length, 16);
    expect(hashes.containsKey('bad'), isFalse);
    expect(hashes['m0'], stableHash('content 0'));
    expect(e.state.value.status, VectorStatus.error);
    expect(e.state.value.lastError, contains('rejected bad memo'));
    expect(e.state.value.embedded, 16);
    expect(e.state.value.total, 17);
    // The failing batch was split, and the pass still reached the rest.
    expect(repo.batches.where((b) => b.length == 1).length, greaterThan(1));
  });

  test('a failing endpoint stops after the first batch', () async {
    for (var i = 0; i < 20; i++) {
      await db.memoDao.upsertLocalMemo('acc-1', memo('m$i', 'content $i'));
    }
    final repo = FakeVectorRepository(configured, failWith: 'HTTP 500 boom');
    final e = await engine(repo);

    // The batch request plus one isolated try per memo in that batch,
    // not a walk of the remaining corpus.
    expect(repo.batches.length, 1 + VectorizationEngine.batchSize);
    expect(repo.batches.first, hasLength(VectorizationEngine.batchSize));
    expect(e.state.value.status, VectorStatus.error);
    expect(e.state.value.lastError, contains('boom'));
    expect(e.state.value.embedded, 0);
    expect(e.state.value.total, 20);
    expect(await db.embeddingDao.embeddedHashes('acc-1', 'e-m'), isEmpty);
  });

  test('auth and rate-limit failures do not fan out per memo', () async {
    for (var i = 0; i < 20; i++) {
      await db.memoDao.upsertLocalMemo('acc-1', memo('m$i', 'content $i'));
    }
    for (final error in [
      const LlmApiException('invalid api key', kind: LlmErrorKind.auth),
      const LlmApiException('slow down', statusCode: 429),
    ]) {
      final repo = _SystemicFailureRepository(configured, error);
      final e = VectorizationEngine(
          accountId: 'acc-1', db: db, repository: repo);
      await e.run();

      expect(repo.batches, hasLength(1));
      expect(repo.batches.single.length, greaterThan(1));
      expect(e.state.value.status, VectorStatus.error);
      expect(e.state.value.lastError, error.message);
      expect(await db.embeddingDao.embeddedHashes('acc-1', 'e-m'), isEmpty);
    }
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
