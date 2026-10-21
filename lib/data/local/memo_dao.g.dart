// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memo_dao.dart';

// ignore_for_file: type=lint
mixin _$MemoDaoMixin on DatabaseAccessor<AppDatabase> {
  $MemosTable get memos => attachedDatabase.memos;
  $MemoTagsTable get memoTags => attachedDatabase.memoTags;
  $PendingAttachmentsTable get pendingAttachments =>
      attachedDatabase.pendingAttachments;
  $SyncMetaTable get syncMeta => attachedDatabase.syncMeta;
  $MemoEmbeddingsTable get memoEmbeddings => attachedDatabase.memoEmbeddings;
  $ChatSessionsTable get chatSessions => attachedDatabase.chatSessions;
  $ChatMessagesTable get chatMessages => attachedDatabase.chatMessages;
  $MemoSuggestionsTable get memoSuggestions => attachedDatabase.memoSuggestions;
  MemoDaoManager get managers => MemoDaoManager(this);
}

class MemoDaoManager {
  final _$MemoDaoMixin _db;
  MemoDaoManager(this._db);
  $$MemosTableTableManager get memos =>
      $$MemosTableTableManager(_db.attachedDatabase, _db.memos);
  $$MemoTagsTableTableManager get memoTags =>
      $$MemoTagsTableTableManager(_db.attachedDatabase, _db.memoTags);
  $$PendingAttachmentsTableTableManager get pendingAttachments =>
      $$PendingAttachmentsTableTableManager(
        _db.attachedDatabase,
        _db.pendingAttachments,
      );
  $$SyncMetaTableTableManager get syncMeta =>
      $$SyncMetaTableTableManager(_db.attachedDatabase, _db.syncMeta);
  $$MemoEmbeddingsTableTableManager get memoEmbeddings =>
      $$MemoEmbeddingsTableTableManager(
        _db.attachedDatabase,
        _db.memoEmbeddings,
      );
  $$ChatSessionsTableTableManager get chatSessions =>
      $$ChatSessionsTableTableManager(_db.attachedDatabase, _db.chatSessions);
  $$ChatMessagesTableTableManager get chatMessages =>
      $$ChatMessagesTableTableManager(_db.attachedDatabase, _db.chatMessages);
  $$MemoSuggestionsTableTableManager get memoSuggestions =>
      $$MemoSuggestionsTableTableManager(
        _db.attachedDatabase,
        _db.memoSuggestions,
      );
}
