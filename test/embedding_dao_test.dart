import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/core/utils/stable_hash.dart';
import 'package:memos_go/data/local/app_database.dart';
import 'package:memos_go/data/local/embedding_dao.dart';
import 'package:memos_go/data/models/models.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTests(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seed(List<Memo> memos) async {
    for (final memo in memos) {
      await db.memoDao.upsertLocalMemo('acc-1', memo);
    }
  }

  Memo memo(String uid, String content, {MemoState state = MemoState.normal}) =>
      Memo(name: 'memos/$uid', content: content, state: state,
          createTime: DateTime(2026, 10, 1));

  test('corpus returns only normal, non-empty memos of the account',
      () async {
    await seed([
      memo('a', 'hello'),
      memo('b', ''),
      memo('c', 'deleted one', state: MemoState.deleted),
    ]);
    await db.memoDao.upsertLocalMemo('acc-2', memo('other', 'not mine'));

    final corpus = await db.embeddingDao.corpus('acc-1');
    expect(corpus.map((m) => m.uid), ['a']);
    expect(corpus.single.content, 'hello');
  });

  test('upsertAll roundtrips vectors and hashes per model', () async {
    await seed([memo('a', 'hello'), memo('b', 'world')]);

    await db.embeddingDao.upsertAll('acc-1', 'e-model', [
      EmbeddingWrite(
          uid: 'a',
          contentHash: stableHash('hello'),
          vector: Float32List.fromList([0.1, 0.2])),
      EmbeddingWrite(
          uid: 'b',
          contentHash: stableHash('world'),
          vector: Float32List.fromList([0.3, 0.4])),
    ]);

    final hashes = await db.embeddingDao.embeddedHashes('acc-1', 'e-model');
    expect(hashes['a'], stableHash('hello'));

    final vectors = await db.embeddingDao.vectorsForModel('acc-1', 'e-model');
    expect(vectors.map((v) => v.uid), ['a', 'b']);
    expect(vectors.first.bytes.lengthInBytes, 8);

    // Upserting the same uid replaces the row (PK is (accountId, memoUid,
    // model)).
    await db.embeddingDao.upsertAll('acc-1', 'e-model', [
      EmbeddingWrite(
          uid: 'a',
          contentHash: stableHash('hello'),
          vector: Float32List.fromList([0.9])),
    ]);
    final again = await db.embeddingDao.vectorsForModel('acc-1', 'e-model');
    expect(again.length, 2);
    expect(again.first.uid, 'a');
    expect(again.first.bytes.lengthInBytes, 4);
  });

  test('vectorsForModel separates models and accounts', () async {
    await seed([memo('a', 'x')]);
    await db.embeddingDao.upsertAll('acc-1', 'm1', [
      EmbeddingWrite(
          uid: 'a', contentHash: 1, vector: Float32List.fromList([1]))
    ]);
    await db.embeddingDao.upsertAll('acc-1', 'm2', [
      EmbeddingWrite(
          uid: 'a', contentHash: 1, vector: Float32List.fromList([2]))
    ]);
    await db.embeddingDao.upsertAll('acc-2', 'm1', [
      EmbeddingWrite(
          uid: 'a', contentHash: 1, vector: Float32List.fromList([3]))
    ]);

    expect((await db.embeddingDao.vectorsForModel('acc-1', 'm1')).length, 1);
    expect((await db.embeddingDao.vectorsForModel('acc-1', 'm2')).length, 1);
    expect((await db.embeddingDao.vectorsForModel('acc-2', 'm1')).length, 1);
  });

  test('deleteOrphans drops rows whose memo is gone', () async {
    await db.embeddingDao.upsertAll('acc-1', 'm', [
      EmbeddingWrite(
          uid: 'ghost', contentHash: 1, vector: Float32List.fromList([1])),
    ]);
    await db.embeddingDao.deleteOrphans('acc-1');
    expect(await db.embeddingDao.embeddedHashes('acc-1', 'm'), isEmpty);
  });

  test('deleteAllForAccount only touches that account', () async {
    await db.embeddingDao.upsertAll('acc-1', 'm', [
      EmbeddingWrite(
          uid: 'a', contentHash: 1, vector: Float32List.fromList([1]))
    ]);
    await db.embeddingDao.upsertAll('acc-2', 'm', [
      EmbeddingWrite(
          uid: 'a', contentHash: 1, vector: Float32List.fromList([1]))
    ]);
    await db.embeddingDao.deleteAllForAccount('acc-1');
    expect(await db.embeddingDao.embeddedHashes('acc-1', 'm'), isEmpty);
    expect(await db.embeddingDao.embeddedHashes('acc-2', 'm'), isNotEmpty);
  });

  test('memo delete paths clean embedding rows', () async {
    await seed([memo('a', 'x')]);
    await db.embeddingDao.upsertAll('acc-1', 'm', [
      EmbeddingWrite(
          uid: 'a', contentHash: 1, vector: Float32List.fromList([1])),
    ]);
    await db.memoDao.deleteLocalMemo('acc-1', 'a');
    expect(await db.embeddingDao.embeddedHashes('acc-1', 'm'), isEmpty);
  });

  test('recordsByUids keeps input order and skips missing', () async {
    await seed([memo('a', 'AAA'), memo('b', 'BBB')]);
    final records =
        await db.memoDao.recordsByUids('acc-1', ['b', 'missing', 'a']);
    expect(records.map((r) => r.memo.uid), ['b', 'a']);
  });
}
