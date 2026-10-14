import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

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

@DriftDatabase(
  tables: [Memos, MemoTags, PendingAttachments, SyncMeta],
  daos: [MemoDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Variant for widget tests: closes query streams synchronously so
  /// drift's deferred cleanup timers never trip the test binding's
  /// "timers pending" invariant.
  AppDatabase.forTests(QueryExecutor e)
      : super(DatabaseConnection(e, closeStreamsSynchronously: true));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Future schema versions migrate here.
        },
      );

  /// Opens the on-disk app database (single instance owned by a provider).
  static AppDatabase open() => AppDatabase(driftDatabase(name: 'memos_go'));
}
