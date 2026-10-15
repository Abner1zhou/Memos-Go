import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'chat_dao.dart';
import 'embedding_dao.dart';
import 'memo_dao.dart';

part 'app_database.g.dart';

/// Row-level sync states for the local memo mirror.
class SyncStates {
  SyncStates._();

  /// Matches the server; safe to overwrite from a pull.
  static const synced = 'synced';

  /// Created locally, not yet accepted by the server.
  static const pendingCreate = 'pendingCreate';

  /// Edited locally; the local version wins over the server until pushed.
  static const pendingUpdate = 'pendingUpdate';

  /// Soft-deleted locally (state column already DELETED); delete not pushed.
  static const pendingDelete = 'pendingDelete';

  static bool isPending(String value) => value != synced;
}

/// Local mirror of the account's memos, keyed by `(accountId, uid)`.
///
/// `uid` is the server-assigned uid once known; offline creations use a
/// locally generated uid (see the sync engine) that the server accepts as
/// `memo_id`, so the key usually survives the round trip unchanged.
@DataClassName('MemosRow')
@TableIndex(name: 'idx_memos_list', columns: {#accountId, #state, #pinned, #createTime})
class Memos extends Table {
  TextColumn get accountId => text()();
  TextColumn get uid => text()();

  /// Memo state wire name: NORMAL / ARCHIVED / DELETED.
  TextColumn get state => text().withDefault(const Constant('NORMAL'))();
  TextColumn get content => text()();
  TextColumn get visibility => text().withDefault(const Constant('PRIVATE'))();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();

  /// JSON-encoded list of server-known attachments.
  TextColumn get attachments => text().withDefault(const Constant('[]'))();

  /// Set when the intended attachment set diverged from the server and a
  /// push must replay `setMemoAttachments`.
  BoolColumn get attachmentsDirty =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get createTime => dateTime().nullable()();

  /// Server-side update time, used for conflict detection.
  DateTimeColumn get updateTime => dateTime().nullable()();

  /// When the local (offline) edit was made; null once synced.
  DateTimeColumn get editedAt => dateTime().nullable()();

  TextColumn get syncState =>
      text().withDefault(const Constant(SyncStates.synced))();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {accountId, uid};
}

/// Normalized memo tags for exact tag filtering and aggregation.
@TableIndex(name: 'idx_memo_tags_tag', columns: {#accountId, #tag})
class MemoTags extends Table {
  TextColumn get accountId => text()();
  TextColumn get memoUid => text()();
  TextColumn get tag => text()();

  @override
  Set<Column> get primaryKey => {accountId, memoUid, tag};
}

/// Attachments captured offline that still need to be uploaded and attached.
class PendingAttachments extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get memoUid => text()();
  TextColumn get filename => text()();
  TextColumn get mimeType => text()();
  TextColumn get localPath => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Per-account sync bookkeeping.
@DataClassName('SyncMetaRow')
class SyncMeta extends Table {
  TextColumn get accountId => text()();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();
  TextColumn get lastResult => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {accountId};
}

/// Per-memo embedding vectors keyed by `(accountId, memoUid, model)`. One
/// row per memo per model; stale-model rows are swept by the vectorization
/// engine after a completed pass, and a `contentHash` mismatch triggers
/// re-embedding.
@DataClassName('MemoEmbeddingsRow')
@TableIndex(name: 'idx_memo_embeddings_account', columns: {#accountId, #model})
class MemoEmbeddings extends Table {
  TextColumn get accountId => text()();
  TextColumn get memoUid => text()();
  TextColumn get model => text()();
  IntColumn get contentHash => integer()();
  BlobColumn get vector => blob()();
  DateTimeColumn get embeddedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {accountId, memoUid, model};
}

/// One local chat conversation with the memories (never synced).
@DataClassName('ChatSessionsRow')
class ChatSessions extends Table {
  TextColumn get accountId => text()();
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {accountId, id};
}

/// One turn in a chat session; [sources] is the JSON citations payload of
/// assistant answers (see [ChatSource] in chat_dao.dart).
@DataClassName('ChatMessagesRow')
@TableIndex(name: 'idx_chat_messages_session', columns: {#accountId, #sessionId, #seq})
class ChatMessages extends Table {
  TextColumn get accountId => text()();
  TextColumn get sessionId => text()();
  IntColumn get seq => integer()();
  TextColumn get role => text()();
  TextColumn get content => text()();
  TextColumn get sources => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {accountId, sessionId, seq};
}

@DriftDatabase(
  tables: [
    Memos,
    MemoTags,
    PendingAttachments,
    SyncMeta,
    MemoEmbeddings,
    ChatSessions,
    ChatMessages,
  ],
  daos: [MemoDao, EmbeddingDao, ChatDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Variant for widget tests: closes query streams synchronously so
  /// drift's deferred cleanup timers never trip the test binding's
  /// "timers pending" invariant.
  AppDatabase.forTests(QueryExecutor e)
      : super(DatabaseConnection(e, closeStreamsSynchronously: true));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(memoEmbeddings);
            // drift's Migrator has no customStatement; the database's own
            // method is the same call. SQL kept idempotent for upgrades.
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_memo_embeddings_account '
                'ON memo_embeddings (account_id, model)');
          }
          if (from < 3) {
            await m.createTable(chatSessions);
            await m.createTable(chatMessages);
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_chat_messages_session '
                'ON chat_messages (account_id, session_id, seq)');
          }
        },
      );

  /// Opens the on-disk app database (single instance owned by a provider).
  static AppDatabase open() => AppDatabase(driftDatabase(name: 'memos_go'));
}
