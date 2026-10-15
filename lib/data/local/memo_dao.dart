import 'package:drift/drift.dart';

import '../models/models.dart';
import 'app_database.dart';
import 'memo_codec.dart';

part 'memo_dao.g.dart';

/// One page of local memos plus whether more rows follow.
class MemoSlice {
  const MemoSlice({required this.records, required this.hasMore});

  final List<MemoRecord> records;
  final bool hasMore;
}

/// All local-database access for the memo mirror. Every query is scoped by
/// [accountId] so multiple server accounts share one database file safely.
@DriftAccessor(tables: [
  Memos,
  MemoTags,
  PendingAttachments,
  SyncMeta,
  MemoEmbeddings,
  ChatSessions,
  ChatMessages,
])
class MemoDao extends DatabaseAccessor<AppDatabase> with _$MemoDaoMixin {
  MemoDao(super.db);

  // ---------------------------------------------------------------- reads

  /// Watches a page of memos ordered like the server feed
  /// (`pinned desc, create_time desc`). [state] is a wire name; null means
  /// the home feed (NORMAL only). [query] is an exact substring filter on
  /// content, [tag] an exact tag match.
  Stream<MemoSlice> watchPage({
    required String accountId,
    int limit = 50,
    int offset = 0,
    String? query,
    String? tag,
    String? state,
  }) {
    final rows = _pageQuery(
      accountId: accountId,
      // Fetch one extra row to learn whether another page follows.
      limit: limit + 1,
      offset: offset,
      query: query,
      tag: tag,
      state: state,
    );
    return rows.watch().asyncMap((list) async {
      final page = list.length > limit ? list.sublist(0, limit) : list;
      return MemoSlice(
          records: await _withTags(accountId, page),
          hasMore: list.length > limit);
    });
  }

  /// One-shot variant of [watchPage] for non-reactive callers.
  Future<MemoSlice> readPage({
    required String accountId,
    int limit = 50,
    int offset = 0,
    String? query,
    String? tag,
    String? state,
  }) async {
    final rows = await _pageQuery(
      accountId: accountId,
      limit: limit + 1,
      offset: offset,
      query: query,
      tag: tag,
      state: state,
    ).get();
    final page = rows.length > limit ? rows.sublist(0, limit) : rows;
    return MemoSlice(
        records: await _withTags(accountId, page),
        hasMore: rows.length > limit);
  }

  /// Watches a single memo (any sync state) by uid.
  Stream<MemoRecord?> watchMemo(String accountId, String uid) {
    final query = select(memos)
      ..where((r) => r.accountId.equals(accountId) & r.uid.equals(uid));
    return query.watchSingleOrNull().asyncMap((row) async {
      if (row == null) return null;
      return (await _withTags(accountId, [row])).single;
    });
  }

  /// Memos by uid in the given order; missing uids are skipped. Used by
  /// semantic search to materialize similarity-ranked hits. Archived and
  /// deleted memos stay invisible, matching the home feed.
  Future<List<MemoRecord>> recordsByUids(
      String accountId, List<String> uids) async {
    if (uids.isEmpty) return const [];
    final query = select(memos)
      ..where((r) =>
          r.accountId.equals(accountId) &
          r.uid.isIn(uids) &
          r.state.equals(MemoState.normal.wireName));
    final rows = await query.get();
    final byUid = {
      for (final record in await _withTags(accountId, rows))
        record.memo.uid: record,
    };
    return [
      for (final uid in uids)
        if (byUid[uid] != null) byUid[uid]!,
    ];
  }

  /// Watches every normal memo for local aggregation (insights, tags).
  Stream<List<MemoRecord>> watchAll(String accountId) {
    final query = select(memos)
      ..where((r) =>
          r.accountId.equals(accountId) &
          r.state.equals(MemoState.normal.wireName))
      ..orderBy([
        (r) => OrderingTerm.desc(r.pinned),
        (r) => OrderingTerm.desc(r.createTime),
        (r) => OrderingTerm.desc(r.uid),
      ]);
    return query.watch().asyncMap((l) => _withTags(accountId, l));
  }

  /// Number of memos not yet pushed to the server.
  Stream<int> watchPendingCount(String accountId) {
    final query = selectOnly(memos)
      ..addColumns([countAll()])
      ..where(memos.accountId.equals(accountId) &
          memos.syncState.equals(SyncStates.synced).not());
    return query.watchSingle().map((row) => row.read(countAll()) ?? 0);
  }

  /// Pending memos ordered for replay: creates, then updates, then deletes,
  /// each by the time they were last edited.
  Future<List<MemoRecord>> pendingMemos(String accountId) async {
    final query = select(memos)
      ..where((r) =>
          r.accountId.equals(accountId) &
          r.syncState.equals(SyncStates.synced).not());
    final rows = await query.get();
    const rank = {
      SyncStates.pendingCreate: 0,
      SyncStates.pendingUpdate: 1,
      SyncStates.pendingDelete: 2,
    };
    rows.sort((a, b) {
      final byState =
          (rank[a.syncState] ?? 3).compareTo(rank[b.syncState] ?? 3);
      if (byState != 0) return byState;
      final at = a.editedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.editedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return at.compareTo(bt);
    });
    return _withTags(accountId, rows);
  }

  /// A memo row by uid, if present (used by the cached repository).
  Future<MemoRecord?> getMemo(String accountId, String uid) async {
    final query = select(memos)
      ..where((r) => r.accountId.equals(accountId) & r.uid.equals(uid));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return (await _withTags(accountId, [row])).single;
  }

  Stream<SyncMetaRow> watchSyncMeta(String accountId) {
    final query = select(syncMeta)
      ..where((m) => m.accountId.equals(accountId));
    return query.watchSingleOrNull().map(
        (row) => row ?? SyncMetaRow(accountId: accountId, lastResult: ''));
  }

  // --------------------------------------------------------------- writes

  /// Inserts or replaces a memo from a local write (offline queue or
  /// hydration after a successful server call). Pending attachments in
  /// [memo].attachments go to the side table; only server-known ones are
  /// stored on the row.
  Future<void> upsertLocalMemo(
    String accountId,
    Memo memo, {
    String syncState = SyncStates.synced,
    DateTime? editedAt,
    Value<bool>? attachmentsDirty,
  }) =>
      transaction(() async {
        await _upsertRowAndTags(accountId, memo,
            syncState: syncState,
            editedAt: editedAt,
            attachmentsDirty: attachmentsDirty);
        await replacePendingAttachments(accountId, memo.uid, memo.attachments);
      });

  /// Replaces the memo's offline-captured attachment queue: only entries
  /// with a [Attachment.localPath] are kept, ordered as given.
  Future<void> replacePendingAttachments(
      String accountId, String memoUid, List<Attachment> attachments) async {
    await (delete(pendingAttachments)
          ..where((p) =>
              p.accountId.equals(accountId) & p.memoUid.equals(memoUid)))
        .go();
    final pendings = attachments.where((a) => a.isPendingUpload).toList();
    if (pendings.isEmpty) return;
    await batch((b) => b.insertAll(
          pendingAttachments,
          [
            for (var index = 0; index < pendings.length; index++)
              PendingAttachmentsCompanion.insert(
                id: pendings[index].uid,
                accountId: accountId,
                memoUid: memoUid,
                filename: pendings[index].filename,
                mimeType: pendings[index].type,
                localPath: pendings[index].localPath!,
                sortOrder: Value(index),
              ),
          ],
          mode: InsertMode.insertOrIgnore,
        ));
  }

  /// Offline-captured attachments queued for one memo.
  Future<List<Attachment>> pendingAttachmentsFor(
      String accountId, String memoUid) async {
    final query = select(pendingAttachments)
      ..where((p) =>
          p.accountId.equals(accountId) & p.memoUid.equals(memoUid))
      ..orderBy([(p) => OrderingTerm.asc(p.sortOrder)]);
    final rows = await query.get();
    return [
      for (final row in rows)
        Attachment(
          name: 'pending/${row.id}',
          filename: row.filename,
          type: row.mimeType,
          localPath: row.localPath,
        ),
    ];
  }

  /// Drops the pending-attachment queue of a memo (after a successful
  /// push; the files themselves are the engine's to clean up).
  Future<void> deletePendingAttachments(String accountId, String memoUid) =>
      (delete(pendingAttachments)
            ..where((p) =>
                p.accountId.equals(accountId) & p.memoUid.equals(memoUid)))
          .go();

  /// Merges one page of server memos: pending local rows win, everything
  /// else is overwritten with the server version.
  Future<void> applyServerPull(String accountId, List<Memo> serverMemos) =>
      transaction(() async {
        if (serverMemos.isEmpty) return;
        final uids = serverMemos.map((m) => m.uid).toList();
        final existing = await (select(memos)
              ..where((r) =>
                  r.accountId.equals(accountId) & r.uid.isIn(uids)))
            .get();
        final pendingUids = existing
            .where((row) => SyncStates.isPending(row.syncState))
            .map((row) => row.uid)
            .toSet();
        final now = DateTime.now();
        for (final memo in serverMemos) {
          if (pendingUids.contains(memo.uid)) continue;
          await _upsertRowAndTags(accountId, memo, syncedAt: now);
        }
      });

  /// Marks a pushed memo as synced, re-keying the row when the server
  /// assigned a different uid than our local one.
  Future<void> markSyncedFromServer(
    String accountId, {
    required String localUid,
    required Memo serverMemo,
  }) =>
      transaction(() async {
        final now = DateTime.now();
        if (serverMemo.uid != localUid) {
          // Server ignored our memo_id: re-key the row and its side tables.
          await (update(memos)..where((r) =>
                  r.accountId.equals(accountId) & r.uid.equals(localUid)))
              .write(MemosCompanion(uid: Value(serverMemo.uid)));
          await (update(memoTags)
                ..where((t) =>
                    t.accountId.equals(accountId) & t.memoUid.equals(localUid)))
              .write(MemoTagsCompanion(memoUid: Value(serverMemo.uid)));
          await (update(pendingAttachments)..where((p) =>
                  p.accountId.equals(accountId) & p.memoUid.equals(localUid)))
              .write(
                  PendingAttachmentsCompanion(memoUid: Value(serverMemo.uid)));
          await (update(memoEmbeddings)
                ..where((e) =>
                    e.accountId.equals(accountId) &
                    e.memoUid.equals(localUid)))
              .write(MemoEmbeddingsCompanion(memoUid: Value(serverMemo.uid)));
        }
        await _upsertRowAndTags(accountId, serverMemo,
            syncedAt: now, attachmentsDirty: const Value(false));
        await deletePendingAttachments(accountId, serverMemo.uid);
      });

  /// Full-pull reconciliation: synced rows absent from every pass are gone
  /// on the server and are removed locally.
  Future<void> sweep(
    String accountId, {
    required Set<String> liveUids,
    required Set<String> deletedUids,
  }) =>
      transaction(() async {
        await (delete(memos)..where((r) =>
            r.accountId.equals(accountId) &
            r.syncState.equals(SyncStates.synced) &
            r.state.isIn(
                [MemoState.normal.wireName, MemoState.archived.wireName]) &
            r.uid.isNotIn(liveUids) &
            r.uid.isNotIn(deletedUids))).go();
        await (delete(memos)..where((r) =>
            r.accountId.equals(accountId) &
            r.syncState.equals(SyncStates.synced) &
            r.state.equals(MemoState.deleted.wireName) &
            r.uid.isNotIn(deletedUids))).go();
        // Side-table rows for memos that no longer exist.
        final remaining = selectOnly(memos)
          ..addColumns([memos.uid])
          ..where(memos.accountId.equals(accountId));
        await (delete(memoTags)..where((t) =>
                t.accountId.equals(accountId) &
                t.memoUid.isNotInQuery(remaining))).go();
        // Same predicate as EmbeddingDao.corpus: only normal, non-empty
        // memos ever earn a vector, so anything else is an orphan.
        final remainingEmbeddings = selectOnly(memos)
          ..addColumns([memos.uid])
          ..where(memos.accountId.equals(accountId) &
              memos.state.equals(MemoState.normal.wireName) &
              memos.content.equals('').not());
        await (delete(memoEmbeddings)..where((e) =>
                e.accountId.equals(accountId) &
                e.memoUid.isNotInQuery(remainingEmbeddings))).go();
      });

  /// Removes all local data of an account (called on account removal).
  Future<void> purgeAccount(String accountId) => transaction(() async {
        await (delete(memos)..where((r) => r.accountId.equals(accountId))).go();
        await (delete(memoTags)
              ..where((t) => t.accountId.equals(accountId)))
            .go();
        await (delete(pendingAttachments)
              ..where((p) => p.accountId.equals(accountId)))
            .go();
        await (delete(syncMeta)..where((m) => m.accountId.equals(accountId)))
            .go();
        await (delete(memoEmbeddings)
              ..where((e) => e.accountId.equals(accountId)))
            .go();
        await (delete(chatMessages)
              ..where((m) => m.accountId.equals(accountId)))
            .go();
        await (delete(chatSessions)
              ..where((s) => s.accountId.equals(accountId)))
            .go();
      });

  /// Deletes a single local row and its side-table rows, used when a
  /// never-pushed creation is deleted offline.
  Future<void> deleteLocalMemo(String accountId, String uid) =>
      transaction(() async {
        await (delete(memos)
              ..where((r) =>
                  r.accountId.equals(accountId) & r.uid.equals(uid)))
            .go();
        await (delete(memoTags)
              ..where((t) =>
                  t.accountId.equals(accountId) & t.memoUid.equals(uid)))
            .go();
        await (delete(pendingAttachments)
              ..where((p) =>
                  p.accountId.equals(accountId) & p.memoUid.equals(uid)))
            .go();
        await (delete(memoEmbeddings)
              ..where((e) =>
                  e.accountId.equals(accountId) & e.memoUid.equals(uid)))
            .go();
      });

  Future<void> setSyncMeta(
      String accountId, DateTime at, String result) async {
    final exists = await (select(syncMeta)
          ..where((m) => m.accountId.equals(accountId)))
        .getSingleOrNull();
    if (exists == null) {
      await into(syncMeta).insert(SyncMetaCompanion.insert(
          accountId: accountId,
          lastSyncAt: Value(at),
          lastResult: Value(result)));
    } else {
      await (update(syncMeta)..where((m) => m.accountId.equals(accountId)))
          .write(SyncMetaCompanion(
              lastSyncAt: Value(at), lastResult: Value(result)));
    }
  }

  // -------------------------------------------------------------- helpers

  SimpleSelectStatement<$MemosTable, MemosRow> _pageQuery({
    required String accountId,
    required int limit,
    required int offset,
    String? query,
    String? tag,
    String? state,
  }) {
    final pageQuery = select(memos)
      ..where((r) =>
          r.accountId.equals(accountId) &
          r.state.equals(state?.isNotEmpty == true
              ? state!
              : MemoState.normal.wireName));

    final q = query?.trim() ?? '';
    if (q.isNotEmpty) {
      pageQuery
          .where((r) => r.content.like(_likePattern(q), escapeChar: r'\'));
    }
    final t = tag?.trim() ?? '';
    if (t.isNotEmpty) {
      final tagUids = selectOnly(memoTags)
        ..addColumns([memoTags.memoUid])
        ..where(memoTags.accountId.equals(accountId) &
            memoTags.tag.equals(t));
      pageQuery.where((r) => r.uid.isInQuery(tagUids));
    }
    pageQuery
      ..orderBy([
        (r) => OrderingTerm.desc(r.pinned),
        (r) => OrderingTerm.desc(r.createTime),
        (r) => OrderingTerm.desc(r.uid),
      ])
      ..limit(limit, offset: offset);
    return pageQuery;
  }

  /// LIKE pattern with `%`, `_` and `\` escaped so the query matches
  /// literally; must be used with `escapeChar: '\'`.
  String _likePattern(String value) {
    final escaped = value
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    return '%$escaped%';
  }

  Future<List<MemoRecord>> _withTags(
      String accountId, List<MemosRow> rows) async {
    if (rows.isEmpty) return const [];
    final uids = rows.map((r) => r.uid).toList();
    final tagRows = await (selectOnly(memoTags)
          ..addColumns([memoTags.memoUid, memoTags.tag])
          ..where(memoTags.accountId.equals(accountId) &
              memoTags.memoUid.isIn(uids)))
        .get();
    final tagsByUid = <String, List<String>>{};
    for (final row in tagRows) {
      final uid = row.read(memoTags.memoUid)!;
      final tag = row.read(memoTags.tag)!;
      (tagsByUid[uid] ??= []).add(tag);
    }
    final pendingRows = await (select(pendingAttachments)
          ..where((p) =>
              p.accountId.equals(accountId) & p.memoUid.isIn(uids))
          ..orderBy([(p) => OrderingTerm.asc(p.sortOrder)]))
        .get();
    final pendingByUid = <String, List<Attachment>>{};
    for (final row in pendingRows) {
      (pendingByUid[row.memoUid] ??= []).add(Attachment(
        name: 'pending/${row.id}',
        filename: row.filename,
        type: row.mimeType,
        localPath: row.localPath,
      ));
    }
    return rows
        .map((row) => MemoRecord(
              memo: rowToMemo(
                row,
                tags: tagsByUid[row.uid] ?? const [],
                pendingAttachments: pendingByUid[row.uid] ?? const [],
              ),
              syncState: row.syncState,
              attachmentsDirty: row.attachmentsDirty,
            ))
        .toList();
  }

  Future<void> _upsertRowAndTags(
    String accountId,
    Memo memo, {
    String syncState = SyncStates.synced,
    DateTime? editedAt,
    DateTime? syncedAt,
    Value<bool>? attachmentsDirty,
  }) async {
    final (_, pendings) = splitPendingAttachments(memo.attachments);
    final rowMemo = pendings.isEmpty
        ? memo
        : Memo(
            name: memo.name,
            state: memo.state,
            creator: memo.creator,
            content: memo.content,
            visibility: memo.visibility,
            pinned: memo.pinned,
            tags: memo.tags,
            createTime: memo.createTime,
            updateTime: memo.updateTime,
          );
    await into(memos).insertOnConflictUpdate(memoToCompanion(
      accountId,
      rowMemo,
      syncState: syncState,
      editedAt: editedAt,
      syncedAt: syncedAt == null ? null : Value(syncedAt),
      attachmentsDirty: attachmentsDirty ?? (pendings.isEmpty ? const Value.absent() : const Value(true)),
    ));
    await (delete(memoTags)
          ..where((t) =>
              t.accountId.equals(accountId) & t.memoUid.equals(memo.uid)))
        .go();
    await batch((b) => b.insertAll(
          memoTags,
          memo.tags
              .map((tag) => MemoTagsCompanion.insert(
                  accountId: accountId, memoUid: memo.uid, tag: tag))
              .toList(),
          mode: InsertMode.insertOrIgnore,
        ));
  }
}
