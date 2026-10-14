import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import '../api/memos_api_client.dart';
import '../local/app_database.dart';
import '../local/memo_codec.dart' show MemoRecord;
import '../local/memo_dao.dart';
import '../models/models.dart';
import '../repositories/memo_repository.dart';

enum SyncPhase { idle, pushing, pulling }

/// Reconciles the local mirror with the server for one account.
///
/// A cycle pushes pending local writes (creates, updates, deletes, in that
/// order) and then pulls the full server state in three passes (NORMAL,
/// ARCHIVED, DELETED) followed by a reconciliation sweep. Runs are
/// single-flight; triggers are debounced.
class SyncEngine {
  SyncEngine({
    required this._accountId,
    required this._server,
    required AppDatabase db,
  }) : _dao = db.memoDao;
  final String _accountId;
  final MemoRepository _server;
  final MemoDao _dao;

  final ValueNotifier<SyncPhase> phase = ValueNotifier(SyncPhase.idle);
  String? lastError;

  bool _running = false;
  Timer? _debounce;
  int _pullPageSize = 1000;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<int>? _pendingSub;
  AppLifecycleListener? _lifecycleListener;

  /// Starts listening for sync triggers (connectivity, app resume, local
  /// writes) and kicks off an initial sync.
  void start() {
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((results) {
      final online =
          results.any((r) => r != ConnectivityResult.none);
      if (online) scheduleSync();
    });
    _lifecycleListener =
        AppLifecycleListener(onResume: () => scheduleSync());
    // The queue itself is the write signal: a growing pending count means
    // something local needs pushing (no coupling with the repository).
    var lastCount = -1;
    _pendingSub = _dao.watchPendingCount(_accountId).listen((count) {
      if (lastCount >= 0 && count > lastCount) scheduleSync();
      lastCount = count;
    });
    scheduleSync();
  }

  /// Debounced sync request, e.g. after a burst of local writes.
  void scheduleSync({Duration delay = const Duration(seconds: 2)}) {
    _debounce?.cancel();
    _debounce = Timer(delay, sync);
  }

  /// Runs one full cycle. Returns true when it completed without errors;
  /// never throws — failures are recorded in [lastError] and sync meta.
  Future<bool> sync() async {
    if (_running) return false;
    _running = true;
    try {
      lastError = null;
      await _push();
      phase.value = SyncPhase.pulling;
      final live = <String>{
        ...await _pullPass(null),
      };
      // Sweep decisions need complete knowledge of every server state, so
      // a skipped pass (older server) disables reconciliation for this run.
      var sweepEligible = true;
      final archived =
          await _pullPass(_stateFilter(MemoState.archived), onSkip: () => sweepEligible = false);
      final deleted = await _pullPass(_stateFilter(MemoState.deleted), onSkip: () => sweepEligible = false);
      if (sweepEligible) {
        live.addAll(archived);
        await _dao.sweep(_accountId,
            liveUids: live, deletedUids: deleted);
      }
      await _dao.setSyncMeta(_accountId, DateTime.now(), 'ok');
      return true;
    } catch (e) {
      lastError = e.toString();
      await _dao.setSyncMeta(_accountId, DateTime.now(), lastError!);
      return false;
    } finally {
      phase.value = SyncPhase.idle;
      _running = false;
    }
  }

  Future<void> dispose() async {
    _debounce?.cancel();
    await _connectivitySub?.cancel();
    await _pendingSub?.cancel();
    _lifecycleListener?.dispose();
  }

  // ----------------------------------------------------------------- push

  Future<void> _push() async {
    final pending = await _dao.pendingMemos(_accountId);
    if (pending.isEmpty) return;
    phase.value = SyncPhase.pushing;
    for (final record in pending) {
      final memo = record.memo;
      try {
        switch (record.syncState) {
          case SyncStates.pendingCreate:
            await _pushCreate(memo.uid, memo.content, memo.visibility, memo);
          case SyncStates.pendingUpdate:
            try {
              await _pushUpdate(record);
            } on MemosApiException catch (e) {
              if (!e.isNotFound) rethrow;
              // Deleted from another device in the meantime: recreate the
              // memo from the local version instead of dropping the edit.
              await _pushCreate(memo.uid, memo.content, memo.visibility, memo);
            }
          case SyncStates.pendingDelete:
            try {
              await _server.deleteMemo(memo.uid);
            } on MemosApiException catch (e) {
              if (!e.isNotFound) rethrow;
            }
            // Soft-deleted server-side; the DELETED pull pass re-imports it
            // as a synced tombstone.
            await _dao.deleteLocalMemo(_accountId, memo.uid);
        }
      } on MemosApiException catch (e) {
        // A row the server rejects outright (e.g. empty content after a
        // policy change) must not block the rest of the queue or pulls.
        // It stays pending and stays visible in the sync status.
        if (e.statusCode != null && e.statusCode! >= 400 && e.statusCode! < 500) {
          lastError = 'push ${memo.uid}: ${e.message}';
          continue;
        }
        rethrow;
      }
    }
  }

  Future<void> _pushCreate(
      String localUid, String content, MemoVisibility visibility, Memo memo) async {
    // Capture the queue (with file paths) before markSynced clears the rows.
    final rows = await _dao.pendingAttachmentsFor(_accountId, localUid);
    final uploaded = await _uploadAll(rows);
    final known = [
      for (final a in memo.attachments)
        if (!a.isPendingUpload) a
    ];
    final created = await _server.createMemo(
      content: content,
      visibility: visibility,
      attachments: [...known, ...uploaded],
      memoId: localUid,
    );
    await _dao.markSyncedFromServer(_accountId,
        localUid: localUid, serverMemo: created);
    await _deleteFiles(rows);
  }

  Future<void> _pushUpdate(MemoRecord record) async {
    final memo = record.memo;
    final rows = await _dao.pendingAttachmentsFor(_accountId, memo.uid);
    final uploaded = await _uploadAll(rows);
    var updated = await _server.updateMemo(memo);
    if (record.attachmentsDirty || uploaded.isNotEmpty) {
      final known = [
        for (final a in memo.attachments)
          if (!a.isPendingUpload) a
      ];
      await _server.updateMemoAttachments(memo.uid, [...known, ...uploaded]);
      updated = updated.copyWith(attachments: [...known, ...uploaded]);
    }
    await _dao.markSyncedFromServer(_accountId,
        localUid: memo.uid, serverMemo: updated);
    await _deleteFiles(rows);
  }

  Future<List<Attachment>> _uploadAll(List<Attachment> pendings) async {
    final uploaded = <Attachment>[];
    for (final attachment in pendings) {
      final bytes = await File(attachment.localPath!).readAsBytes();
      uploaded.add(await _server.uploadAttachment(
        filename: attachment.filename,
        mimeType: attachment.type,
        bytes: bytes,
      ));
    }
    return uploaded;
  }

  Future<void> _deleteFiles(List<Attachment> pendings) async {
    for (final attachment in pendings) {
      try {
        await File(attachment.localPath!).delete();
      } catch (_) {
        // Best-effort cleanup.
      }
    }
  }

  // ----------------------------------------------------------------- pull

  /// Pages through one server state, merging every page into the mirror.
  /// Returns the set of memo uids seen in this pass. [onSkip] fires when
  /// the server rejects this pass's filter (older servers), in which case
  /// an empty set is returned and reconciliation must be disabled.
  Future<Set<String>> _pullPass(String? filter, {void Function()? onSkip}) async {
    var token = '';
    final seen = <String>{};
    while (true) {
      MemoListPage page;
      try {
        page = await _server.listMemos(
            pageSize: _pullPageSize, pageToken: token, filter: filter);
      } on MemosApiException catch (e) {
        if (e.isUnauthorized) rethrow;
        if (token.isEmpty && _pullPageSize > 50) {
          // Older servers reject large page sizes; retry with the default.
          _pullPageSize = 50;
          continue;
        }
        if (onSkip != null &&
            (e.statusCode == null || e.statusCode == 400 || e.isNotFound ||
                e.statusCode == 501)) {
          onSkip();
          return seen;
        }
        rethrow;
      }
      await _dao.applyServerPull(_accountId, page.memos);
      seen.addAll(page.memos.map((m) => m.uid));
      if (page.nextPageToken.isEmpty) break;
      token = page.nextPageToken;
    }
    return seen;
  }

  String? _stateFilter(MemoState state) => buildMemoFilter(state: state.wireName);
}
