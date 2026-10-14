import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../api/memos_api_client.dart' show isNetworkFailure;
import '../local/app_database.dart';
import '../local/memo_codec.dart' show MemoRecord;
import '../local/memo_dao.dart';
import '../models/models.dart';
import 'auth_repository.dart';
import 'memo_repository.dart';

/// Local-first facade over [MemoRepository].
///
/// Reads come from the local mirror (kept fresh by the sync engine) so the
/// UI works offline; writes go to the server first and fall back to the
/// pending queue when the server cannot be reached. Shares the
/// [MemoRepository] interface so existing consumers and tests are unchanged.
class CachedMemoRepository extends MemoRepository {
  CachedMemoRepository({
    required ServerAccount account,
    required this._db,
    MemoRepository? server,
  })  : _serverDelegate = server,
        super(account);

  final AppDatabase _db;
  final MemoRepository? _serverDelegate;

  /// The server facade used for online attempts: the injected one, or a
  /// plain [MemoRepository] over the same account. Tests inject an
  /// unreachable one to force the offline paths deterministically.
  late final MemoRepository _server =
      _serverDelegate ?? MemoRepository(account);

  MemoDao get _dao => _db.memoDao;
  String get _accountId => account.id;

  // ------------------------------------------------------------ local reads

  /// Watches a page of the local mirror; see [MemoDao.watchPage].
  Stream<MemoSlice> watchMemosPage({
    int limit = 50,
    int offset = 0,
    String? query,
    String? tag,
    String? state,
  }) =>
      _dao.watchPage(
        accountId: _accountId,
        limit: limit,
        offset: offset,
        query: query,
        tag: tag,
        state: state,
      );

  /// Watches one memo (any sync state) by uid.
  Stream<MemoRecord?> watchMemo(String uid) =>
      _dao.watchMemo(_accountId, uid);

  /// Watches all normal memos, for aggregation.
  Stream<List<MemoRecord>> watchAllMemos() => _dao.watchAll(_accountId);

  /// Number of memos waiting to be pushed.
  Stream<int> watchPendingCount() => _dao.watchPendingCount(_accountId);

  /// Whether [name] (`memos/{uid}`) still has unsynced local changes; used
  /// by callers to hint "saved offline" after a write.
  Future<bool> isPendingSync(String name) async {
    final record = await _dao.getMemo(_accountId, name.split('/').last);
    return record != null && record.isPending;
  }

  Stream<SyncMetaRow> watchSyncMeta() => _dao.watchSyncMeta(_accountId);

  @override
  Future<Memo> getMemo(String uid) async {
    final local = await _dao.getMemo(_accountId, uid);
    if (local != null) return local.memo;
    final memo = await _server.getMemo(uid);
    await _dao.upsertLocalMemo(_accountId, memo);
    return memo;
  }

  /// Serves [MemoRepository.listMemos] from the local mirror. Only the
  /// state filter (`state == "..."`) is honored; content/tag filters are
  /// ignored because all reactive callers use [watchMemosPage] with
  /// structured parameters. [pageToken] is the local row offset.
  @override
  Future<MemoListPage> listMemos({
    int pageSize = 50,
    String pageToken = '',
    String? filter,
  }) async {
    final offset = int.tryParse(pageToken) ?? 0;
    final state = _stateFilterPattern.firstMatch(filter ?? '')?.group(1);
    final slice = await _dao.readPage(
      accountId: _accountId,
      limit: pageSize,
      offset: offset,
      state: state,
    );
    return MemoListPage(
      memos: slice.records.map((r) => r.memo).toList(),
      nextPageToken: slice.hasMore ? '${offset + pageSize}' : '',
    );
  }

  static final _stateFilterPattern = RegExp(r'state == "([A-Z]+)"');

  // ----------------------------------------------------------------- writes

  @override
  Future<Memo> createMemo({
    required String content,
    required MemoVisibility visibility,
    List<Attachment> attachments = const [],
    String? memoId,
  }) async {
    final pendings = attachments.where((a) => a.isPendingUpload).toList();
    try {
      final known = await _materializeAttachments(attachments);
      final memo = await _server.createMemo(
        content: content,
        visibility: visibility,
        attachments: known,
        memoId: memoId ?? _generateLocalUid(),
      );
      await _dao.upsertLocalMemo(_accountId, memo,
          attachmentsDirty: const Value(false));
      await _deleteFilesQuietly(pendings);
      return memo;
    } catch (e) {
      if (!isNetworkFailure(e)) rethrow;
      final uid = memoId ?? _generateLocalUid();
      final now = DateTime.now();
      final local = Memo(
        name: 'memos/$uid',
        content: content,
        visibility: visibility,
        attachments: attachments,
        createTime: now,
        updateTime: now,
      );
      await _dao.upsertLocalMemo(_accountId, local,
          syncState: SyncStates.pendingCreate, editedAt: now);
      return local;
    }
  }

  @override
  Future<Memo> updateMemo(Memo memo) async {
    final existing = await _dao.getMemo(_accountId, memo.uid);
    if (existing != null && SyncStates.isPending(existing.syncState)) {
      // The server has never seen this version (or this memo at all):
      // keep editing locally, replay happens on the next push. Fields the
      // update mask doesn't cover (tags, attachments) fall back to the
      // stored row so callers that omit them don't wipe data.
      final effective = _mergeUnmaskedFields(memo, existing);
      await _dao.upsertLocalMemo(
        _accountId,
        effective,
        syncState: _nextSyncState(existing.syncState, effective),
        editedAt: DateTime.now(),
        attachmentsDirty: Value(existing.attachmentsDirty ||
            _attachmentsChanged(
                existing.memo.attachments, effective.attachments)),
      );
      return effective;
    }
    final pendings = memo.attachments.where((a) => a.isPendingUpload).toList();
    try {
      final known = await _materializeAttachments(memo.attachments);
      var updated = await _server.updateMemo(memo);
      if (updated.attachments.isEmpty && known.isNotEmpty) {
        updated = updated.copyWith(attachments: known);
      }
      if (_attachmentsChanged(existing?.memo.attachments ?? const [], known)) {
        await _server.updateMemoAttachments(updated.uid, known);
        updated = updated.copyWith(attachments: known);
      }
      await _dao.upsertLocalMemo(_accountId, updated,
          attachmentsDirty: const Value(false));
      await _deleteFilesQuietly(pendings);
      return updated;
    } catch (e) {
      if (!isNetworkFailure(e)) rethrow;
      final effective = _mergeUnmaskedFields(memo, existing);
      await _dao.upsertLocalMemo(
        _accountId,
        effective,
        syncState: _nextSyncState(existing?.syncState, effective),
        editedAt: DateTime.now(),
        attachmentsDirty: Value(existing?.attachmentsDirty == true ||
            _attachmentsChanged(
                existing?.memo.attachments ?? const [], effective.attachments)),
      );
      return effective;
    }
  }

  /// Local writes replay the server's update-mask contract: tags and
  /// attachments are not part of [MemoRepository.updateMemo]'s mask, so an
  /// incoming memo without them keeps the stored values.
  Memo _mergeUnmaskedFields(Memo memo, MemoRecord? existing) {
    if (existing == null ||
        (memo.tags.isNotEmpty || memo.attachments.isNotEmpty)) {
      return memo;
    }
    return Memo(
      name: memo.name,
      state: memo.state,
      creator: memo.creator,
      content: memo.content,
      visibility: memo.visibility,
      pinned: memo.pinned,
      tags: existing.memo.tags,
      attachments: existing.memo.attachments,
      createTime: memo.createTime,
      updateTime: memo.updateTime,
    );
  }

  @override
  Future<void> updateMemoAttachments(
      String uid, List<Attachment> attachments) async {
    final existing = await _dao.getMemo(_accountId, uid);
    if (existing != null && SyncStates.isPending(existing.syncState)) {
      await _dao.upsertLocalMemo(
        _accountId,
        existing.memo.copyWith(attachments: attachments),
        syncState: existing.syncState,
        editedAt: DateTime.now(),
        attachmentsDirty: const Value(true),
      );
      return;
    }
    final pendings = attachments.where((a) => a.isPendingUpload).toList();
    try {
      final known = await _materializeAttachments(attachments);
      await _server.updateMemoAttachments(uid, known);
      if (existing != null) {
        await _dao.upsertLocalMemo(
            _accountId, existing.memo.copyWith(attachments: known),
            attachmentsDirty: const Value(false));
      }
      await _deleteFilesQuietly(pendings);
    } catch (e) {
      if (!isNetworkFailure(e)) rethrow;
      if (existing != null) {
        await _dao.upsertLocalMemo(
          _accountId,
          existing.memo.copyWith(attachments: attachments),
          syncState: SyncStates.pendingUpdate,
          editedAt: DateTime.now(),
          attachmentsDirty: const Value(true),
        );
      }
    }
  }

  @override
  Future<void> deleteMemo(String uid) async {
    final existing = await _dao.getMemo(_accountId, uid);
    if (existing != null &&
        existing.syncState == SyncStates.pendingCreate) {
      // Never reached the server; no need to keep it.
      await _dao.deleteLocalMemo(_accountId, uid);
      return;
    }
    try {
      await _server.deleteMemo(uid);
      if (existing != null) {
        await _dao.upsertLocalMemo(_accountId,
            existing.memo.copyWith(state: MemoState.deleted),
            attachmentsDirty: const Value(false));
      }
    } catch (e) {
      if (!isNetworkFailure(e)) rethrow;
      if (existing != null) {
        await _dao.upsertLocalMemo(
          _accountId,
          existing.memo.copyWith(state: MemoState.deleted),
          syncState: SyncStates.pendingDelete,
          editedAt: DateTime.now(),
        );
      }
    }
  }

  @override
  Future<Attachment> uploadAttachment({
    required String filename,
    required String mimeType,
    required List<int> bytes,
  }) async {
    try {
      return await _server.uploadAttachment(
          filename: filename, mimeType: mimeType, bytes: bytes);
    } catch (e) {
      if (!isNetworkFailure(e)) rethrow;
      // Queue the file locally; the returned attachment carries its path so
      // UI renders from disk and the next push uploads it.
      final id = const Uuid().v4();
      // Plain Dart tests run without the path_provider plugin; fall back to
      // the temp directory there.
      // ignore: omit_local_variable_types
      Directory base;
      try {
        base = await getApplicationDocumentsDirectory();
      } catch (_) {
        base = Directory.systemTemp;
      }
      final folder = Directory('${base.path}/pending_attachments');
      await folder.create(recursive: true);
      final file = File('${folder.path}/$id');
      await file.writeAsBytes(bytes, flush: true);
      return Attachment(
        name: 'pending/$id',
        filename: filename,
        type: mimeType,
        size: bytes.length,
        localPath: file.path,
      );
    }
  }

  // --------------------------------------------------------------- helpers

  /// Uploads every offline-captured attachment of the set, returning the
  /// full server-known list (order preserved).
  Future<List<Attachment>> _materializeAttachments(
      List<Attachment> attachments) async {
    final known = <Attachment>[];
    for (final attachment in attachments) {
      if (!attachment.isPendingUpload) {
        known.add(attachment);
        continue;
      }
      final bytes = await File(attachment.localPath!).readAsBytes();
      known.add(await _server.uploadAttachment(
        filename: attachment.filename,
        mimeType: attachment.type,
        bytes: bytes,
      ));
    }
    return known;
  }

  bool _attachmentsChanged(List<Attachment> before, List<Attachment> after) {
    Set<String> knownUids(List<Attachment> list) => {
          for (final a in list)
            if (!a.isPendingUpload) a.uid
        };
    final a = knownUids(before);
    final b = knownUids(after);
    return a.length != b.length || !a.containsAll(b) ||
        after.any((x) => x.isPendingUpload);
  }

  Future<void> _deleteFilesQuietly(List<Attachment> pendings) async {
    for (final attachment in pendings) {
      final path = attachment.localPath;
      if (path == null) continue;
      try {
        await File(path).delete();
      } catch (_) {
        // Best-effort cleanup.
      }
    }
  }

  /// Local uid for offline creations. Fits the server's `memo_id` pattern
  /// (`^[a-zA-Z0-9]([a-zA-Z0-9-]{0,34}[a-zA-Z0-9])?$`) so a replay with
  /// `memoId` keeps the same key on both sides.
  String _generateLocalUid() =>
      'l${const Uuid().v4().replaceAll('-', '')}'.substring(0, 33);

  String _nextSyncState(String? current, Memo memo) {
    if (memo.state == MemoState.deleted) return SyncStates.pendingDelete;
    if (current == SyncStates.pendingCreate) return SyncStates.pendingCreate;
    return SyncStates.pendingUpdate;
  }
}
