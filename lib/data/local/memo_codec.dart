import 'dart:convert';

import 'package:drift/drift.dart';

import '../models/models.dart';
import 'app_database.dart';

/// A [Memo] as stored locally, carrying its sync state for the UI/engine.
class MemoRecord {
  const MemoRecord({
    required this.memo,
    required this.syncState,
    this.attachmentsDirty = false,
  });

  final Memo memo;

  /// One of [SyncStates].
  final String syncState;

  /// Whether the attachment set needs replaying on the next push.
  final bool attachmentsDirty;

  bool get isPending => SyncStates.isPending(syncState);
}

/// Converts domain [Memo]s to local rows. Tag lookup lives in a side table
/// and is handled by the DAO; everything else is columnar here.
MemosCompanion memoToCompanion(
  String accountId,
  Memo memo, {
  String syncState = SyncStates.synced,
  DateTime? editedAt,
  Value<DateTime>? syncedAt,
  Value<bool>? attachmentsDirty,
}) =>
    MemosCompanion(
      accountId: Value(accountId),
      uid: Value(memo.uid),
      state: Value(memo.state.wireName),
      content: Value(memo.content),
      visibility: Value(memo.visibility.wireName),
      pinned: Value(memo.pinned),
      attachments: Value(jsonEncode(memo.attachments.map((a) => a.toJson()).toList())),
      attachmentsDirty: attachmentsDirty ?? const Value.absent(),
      createTime: Value(memo.createTime),
      updateTime: Value(memo.updateTime),
      editedAt: Value(editedAt),
      syncState: Value(syncState),
      syncedAt: syncedAt ?? const Value.absent(),
    );

/// Row -> [Memo]. Parsing stays defensive in the spirit of models.dart:
/// a corrupted JSON column must degrade to defaults, never throw.
Memo rowToMemo(MemosRow row, {List<String> tags = const [], List<Attachment> pendingAttachments = const []}) {
  List<Attachment> attachments = const [];
  try {
    final decoded = jsonDecode(row.attachments);
    if (decoded is List) {
      attachments = decoded
          .whereType<Map>()
          .map((e) => Attachment.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
  } catch (_) {
    // Leave attachments empty on malformed JSON.
  }
  return Memo(
    name: 'memos/${row.uid}',
    state: MemoState.fromWire(row.state),
    content: row.content,
    visibility: MemoVisibility.fromWire(row.visibility),
    pinned: row.pinned,
    tags: tags,
    attachments: [...attachments, ...pendingAttachments],
    createTime: row.createTime,
    updateTime: row.updateTime,
  );
}

/// Splits an intended attachment set into server-known attachments (stored
/// in the row JSON) and offline-captured ones (stored in the pending table).
(List<Attachment>, List<Attachment>) splitPendingAttachments(
        List<Attachment> attachments) =>
    (
      [
        for (final a in attachments)
          if (!a.isPendingUpload) a
      ],
      [
        for (final a in attachments)
          if (a.isPendingUpload) a
      ],
    );
