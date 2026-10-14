import 'dart:io' as io;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_go/data/api/memos_api_client.dart';
import 'package:memos_go/data/local/app_database.dart';
import 'package:memos_go/data/models/models.dart';
import 'package:memos_go/data/repositories/auth_repository.dart';
import 'package:memos_go/data/repositories/memo_repository.dart';
import 'package:memos_go/data/sync/sync_engine.dart';

const _accountId = 'http://x|tester';

final _account = ServerAccount(
  id: _accountId,
  baseUrl: 'http://x',
  token: 'tok',
  user: const User(name: 'users/1', username: 'tester'),
);

Memo _memo(
  String uid,
  String content, {
  MemoState state = MemoState.normal,
  List<Attachment> attachments = const [],
  DateTime? createTime,
}) =>
    Memo(
      name: 'memos/$uid',
      state: state,
      content: content,
      attachments: attachments,
      createTime: createTime ?? DateTime(2026, 1, 1),
    );

/// In-memory Memos server: honors `memo_id`, soft-deletes, pages with an
/// offset token, and records calls for assertions.
class _FakeServer extends MemoRepository {
  _FakeServer() : super(_account);

  final Map<String, Memo> memos = {};
  final List<String> calls = [];

  @override
  Future<MemoListPage> listMemos({
    int pageSize = 50,
    String pageToken = '',
    String? filter,
  }) async {
    final deleted = (filter ?? '').contains('DELETED');
    final archived = (filter ?? '').contains('ARCHIVED');
    final matching = memos.values.where((m) => switch (m.state) {
          MemoState.deleted => deleted,
          MemoState.archived => archived,
          MemoState.normal => !deleted && !archived,
        }).toList()
          ..sort((a, b) => b.createTime!.compareTo(a.createTime!));
    final offset = int.tryParse(pageToken) ?? 0;
    final page = offset + pageSize >= matching.length
        ? matching.sublist(offset)
        : matching.sublist(offset, offset + pageSize);
    return MemoListPage(
      memos: page,
      nextPageToken: offset + pageSize < matching.length
          ? '${offset + pageSize}'
          : '',
    );
  }

  @override
  Future<Memo> createMemo({
    required String content,
    required MemoVisibility visibility,
    List<Attachment> attachments = const [],
    String? memoId,
  }) async {
    calls.add('create:$memoId');
    final uid = memoId ?? 'srv${memos.length}';
    final memo = _memo(uid, content, attachments: attachments);
    memos[uid] = memo;
    return memo;
  }

  @override
  Future<Memo> updateMemo(Memo memo) async {
    calls.add('update:${memo.uid}');
    if (!memos.containsKey(memo.uid)) {
      throw MemosApiException('not found', statusCode: 404);
    }
    memos[memo.uid] = memo;
    return memo;
  }

  @override
  Future<void> updateMemoAttachments(
      String uid, List<Attachment> attachments) async {
    calls.add('attachments:$uid');
    final memo = memos[uid];
    if (memo == null) {
      throw MemosApiException('not found', statusCode: 404);
    }
    memos[uid] = memo.copyWith(attachments: attachments);
  }

  @override
  Future<void> deleteMemo(String uid) async {
    calls.add('delete:$uid');
    final memo = memos[uid];
    if (memo == null) {
      throw MemosApiException('not found', statusCode: 404);
    }
    memos[uid] = memo.copyWith(state: MemoState.deleted);
  }

  int attachmentSeq = 0;

  @override
  Future<Attachment> uploadAttachment({
    required String filename,
    required String mimeType,
    required List<int> bytes,
  }) async {
    calls.add('upload:$filename');
    return Attachment(
        name: 'attachments/a${attachmentSeq++}', filename: filename, type: mimeType);
  }
}

void main() {
  late AppDatabase db;
  late _FakeServer server;
  late SyncEngine engine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    server = _FakeServer();
    engine = SyncEngine(accountId: _accountId, server: server, db: db);
  });

  tearDown(() async {
    await db.close();
  });

  test('push replays a pendingCreate with memoId and keeps the uid', () async {
    final local = _memo('labc123', 'offline note');
    await db.memoDao.upsertLocalMemo(_accountId, local,
        syncState: SyncStates.pendingCreate, editedAt: DateTime.now());

    expect(await engine.sync(), isTrue);

    expect(server.calls, ['create:labc123']);
    expect(server.memos.keys, contains('labc123')); // server kept our uid
    final row = await db.memoDao.getMemo(_accountId, 'labc123');
    expect(row!.syncState, SyncStates.synced);
    expect(row.memo.content, 'offline note');
  });

  test('push re-keys the row when the server ignores memoId', () async {
    // Server without memoId support assigns its own uid.
    final reassigning = _ReassigningServer();
    final engine2 =
        SyncEngine(accountId: _accountId, server: reassigning, db: db);
    await db.memoDao.upsertLocalMemo(_accountId, _memo('lxyz', 'queued'),
        syncState: SyncStates.pendingCreate, editedAt: DateTime.now());

    await engine2.sync();

    expect(await db.memoDao.getMemo(_accountId, 'lxyz'), isNull);
    final row = await db.memoDao.getMemo(_accountId, 'srv42');
    expect(row!.syncState, SyncStates.synced);
  });

  test('push recreates a memo that was deleted on the server (404)',
      () async {
    server.memos['m1'] = _memo('m1', 'server copy');
    await db.memoDao.upsertLocalMemo(_accountId, _memo('m1', 'local edit'),
        syncState: SyncStates.pendingUpdate, editedAt: DateTime.now());
    server.memos.remove('m1'); // deleted from another device meanwhile

    await engine.sync();

    expect(server.calls, containsAll(['update:m1', 'create:m1']));
    final row = await db.memoDao.getMemo(_accountId, 'm1');
    expect(row!.syncState, SyncStates.synced);
    expect(row.memo.content, 'local edit');
  });

  test('push applies pendingDelete; trash mirror re-imports the tombstone',
      () async {
    server.memos['m1'] = _memo('m1', 'bye');
    await db.memoDao.upsertLocalMemo(
        _accountId, _memo('m1', 'bye', state: MemoState.deleted),
        syncState: SyncStates.pendingDelete, editedAt: DateTime.now());

    await engine.sync();

    expect(server.calls, contains('delete:m1'));
    expect(server.memos['m1']!.state, MemoState.deleted);
    // The pull re-imported the server tombstone as a synced DELETED row,
    // which is what keeps the trash view working.
    final row = await db.memoDao.getMemo(_accountId, 'm1');
    expect(row!.syncState, SyncStates.synced);
    expect(row.memo.state, MemoState.deleted);
  });

  test('push uploads queued attachments before creating', () async {
    final dir = await io.Directory.systemTemp.createTemp('pending_att');
    final file = io.File('${dir.path}/a1');
    await file.writeAsBytes([1, 2, 3]);
    addTearDown(() async => dir.delete(recursive: true));

    final memo = _memo('latt1', 'with audio');
    await db.memoDao.upsertLocalMemo(_accountId, memo,
        syncState: SyncStates.pendingCreate, editedAt: DateTime.now());
    await db.memoDao.replacePendingAttachments(_accountId, 'latt1', [
      Attachment(
          name: 'pending/a1',
          filename: 'voice.m4a',
          type: 'audio/mp4',
          localPath: file.path),
    ]);

    await engine.sync();

    expect(server.calls, containsAll(['upload:voice.m4a', 'create:latt1']));
    expect(server.memos['latt1']!.attachments.single.filename, 'voice.m4a');
    expect(await file.exists(), isFalse); // cleaned up after upload
    expect(await db.memoDao.pendingAttachmentsFor(_accountId, 'latt1'),
        isEmpty);
  });

  test('pull mirrors server pages and overwrites synced rows', () async {
    for (var i = 0; i < 3; i++) {
      server.memos['m$i'] = _memo('m$i', 'server $i',
          createTime: DateTime(2026, 1, i + 1));
    }
    // Stale local copy that the pull must overwrite.
    await db.memoDao.upsertLocalMemo(_accountId, _memo('m0', 'stale local'));

    expect(await engine.sync(), isTrue);

    final page = await db.memoDao.readPage(accountId: _accountId);
    expect(page.records.length, 3);
    expect(page.records.first.memo.uid, 'm2'); // newest first
    expect(
        page.records.map((r) => r.memo.content), contains('server 0'));
  });

  test('pull keeps pending local rows untouched', () async {
    server.memos['m1'] = _memo('m1', 'server version');
    await db.memoDao.upsertLocalMemo(_accountId, _memo('m1', 'local version'),
        syncState: SyncStates.pendingUpdate, editedAt: DateTime.now());
    // The push is rejected by the server (403), so the row stays pending
    // and the pull must not overwrite it either.
    final rejecting = _RejectingUpdateServer();
    final engine2 = SyncEngine(accountId: _accountId, server: rejecting, db: db);

    await engine2.sync();

    final row = await db.memoDao.getMemo(_accountId, 'm1');
    expect(row!.memo.content, 'local version');
    expect(row.syncState, SyncStates.pendingUpdate);
  });

  test('sweep removes synced rows the server no longer returns', () async {
    await db.memoDao.upsertLocalMemo(_accountId, _memo('gone', 'vanished'));
    await db.memoDao.upsertLocalMemo(_accountId, _memo('keep', 'stays'));
    server.memos['keep'] = _memo('keep', 'stays');

    await engine.sync();

    expect(await db.memoDao.getMemo(_accountId, 'gone'), isNull);
    expect(await db.memoDao.getMemo(_accountId, 'keep'), isNotNull);
  });

  test('skipped optional passes disable the sweep for that run', () async {
    await db.memoDao.upsertLocalMemo(
        _accountId, _memo('arch', 'archived', state: MemoState.archived));
    // Server that rejects the CEL state filter (400) on optional passes.
    final failing = _ThrowingFilterServer();
    final engine2 =
        SyncEngine(accountId: _accountId, server: failing, db: db);
    await engine2.sync();

    // The ARCHIVED pass was skipped; the sweep must not purge the row.
    expect(await db.memoDao.getMemo(_accountId, 'arch'), isNotNull);
  });
}

class _ThrowingFilterServer extends _FakeServer {
  @override
  Future<MemoListPage> listMemos({
    int pageSize = 50,
    String pageToken = '',
    String? filter,
  }) async {
    if (filter != null && filter.isNotEmpty) {
      throw MemosApiException('invalid filter', statusCode: 400);
    }
    return const MemoListPage(memos: []);
  }
}

/// Old server that ignores `memoId` and always assigns its own uid.
class _ReassigningServer extends _FakeServer {
  @override
  Future<Memo> createMemo({
    required String content,
    required MemoVisibility visibility,
    List<Attachment> attachments = const [],
    String? memoId,
  }) async {
    calls.add('create:$memoId');
    final memo = _memo('srv42', content, attachments: attachments);
    memos['srv42'] = memo;
    return memo;
  }
}

/// Server whose update endpoint refuses with 403 (push skips the row).
class _RejectingUpdateServer extends _FakeServer {
  @override
  Future<Memo> updateMemo(Memo memo) async {
    throw MemosApiException('forbidden', statusCode: 403);
  }
}
