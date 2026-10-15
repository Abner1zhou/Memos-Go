import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../models/models.dart';
import 'app_database.dart';

part 'embedding_dao.g.dart';

/// A memo eligible for vectorization: uid + raw content.
class EmbeddableMemo {
  const EmbeddableMemo({required this.uid, required this.content});

  final String uid;
  final String content;
}

/// One vector to persist for a memo.
class EmbeddingWrite {
  const EmbeddingWrite(
      {required this.uid, required this.contentHash, required this.vector});

  final String uid;
  final int contentHash;
  final Float32List vector;
}

/// A stored vector blob for similarity search.
class VectorRow {
  const VectorRow({required this.uid, required this.bytes});

  final String uid;
  final Uint8List bytes;
}

/// All local-database access for the memo embedding index. Every query is
/// scoped by [accountId], mirroring [MemoDao]'s convention.
@DriftAccessor(tables: [MemoEmbeddings, Memos])
class EmbeddingDao extends DatabaseAccessor<AppDatabase>
    with _$EmbeddingDaoMixin {
  EmbeddingDao(super.db);

  /// The vectorization corpus: normal memos with non-empty content.
  Future<List<EmbeddableMemo>> corpus(String accountId) async {
    final rows = await (selectOnly(memos)
          ..addColumns([memos.uid, memos.content])
          ..where(memos.accountId.equals(accountId) &
              memos.state.equals(MemoState.normal.wireName) &
              memos.content.equals('').not()))
        .get();
    return [
      for (final row in rows)
        EmbeddableMemo(
            uid: row.read(memos.uid)!,
            content: row.read(memos.content)!),
    ];
  }

  /// uid -> contentHash for rows already embedded with [model].
  Future<Map<String, int>> embeddedHashes(String accountId, String model) async {
    final rows = await (selectOnly(memoEmbeddings)
          ..addColumns([memoEmbeddings.memoUid, memoEmbeddings.contentHash])
          ..where(memoEmbeddings.accountId.equals(accountId) &
              memoEmbeddings.model.equals(model)))
        .get();
    return {
      for (final row in rows)
        row.read(memoEmbeddings.memoUid)!:
            row.read(memoEmbeddings.contentHash)!,
    };
  }

  /// Inserts or replaces the given vectors (PK `(accountId, memoUid)`).
  Future<void> upsertAll(
      String accountId, String model, List<EmbeddingWrite> rows) {
    final now = DateTime.now();
    return batch((b) => b.insertAll(
          memoEmbeddings,
          [
            for (final row in rows)
              MemoEmbeddingsCompanion.insert(
                accountId: accountId,
                memoUid: row.uid,
                model: model,
                contentHash: row.contentHash,
                vector: row.vector.buffer.asUint8List(
                    row.vector.offsetInBytes, row.vector.lengthInBytes),
                embeddedAt: now,
              ),
          ],
          mode: InsertMode.insertOrReplace,
        ));
  }

  /// All stored vectors for one model (the brute-force search input).
  Future<List<VectorRow>> vectorsForModel(String accountId, String model) async {
    final rows = await (selectOnly(memoEmbeddings)
          ..addColumns([memoEmbeddings.memoUid, memoEmbeddings.vector])
          ..where(memoEmbeddings.accountId.equals(accountId) &
              memoEmbeddings.model.equals(model))
          // Deterministic order: insertOrReplace re-inserts with a fresh
          // rowid, so physical order is not stable across rewrites.
          ..orderBy([OrderingTerm.asc(memoEmbeddings.memoUid)]))
        .get();
    return [
      for (final row in rows)
        VectorRow(
            uid: row.read(memoEmbeddings.memoUid)!,
            bytes: row.read(memoEmbeddings.vector)!),
    ];
  }

  /// Drops embedding rows whose memo no longer exists (server-deleted).
  Future<void> deleteOrphans(String accountId) async {
    final remaining = selectOnly(memos)
      ..addColumns([memos.uid])
      ..where(memos.accountId.equals(accountId));
    await (delete(memoEmbeddings)
          ..where((e) =>
              e.accountId.equals(accountId) &
              e.memoUid.isNotInQuery(remaining)))
        .go();
  }

  Future<void> deleteAllForAccount(String accountId) =>
      (delete(memoEmbeddings)
            ..where((e) => e.accountId.equals(accountId)))
          .go();
}
