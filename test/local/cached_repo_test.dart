import 'dart:io' as io;

import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_go/data/api/memos_api_client.dart';
import 'package:memos_go/data/local/app_database.dart';
import 'package:memos_go/data/models/models.dart';
import 'package:memos_go/data/repositories/auth_repository.dart';
import 'package:memos_go/data/repositories/cached_memo_repository.dart';
import 'package:memos_go/data/repositories/memo_repository.dart';

final _account = ServerAccount(
  id: 'http://x|tester',
  baseUrl: 'http://x',
  token: 'tok',
  user: const User(name: 'users/1', username: 'tester'),
);

Never _networkFail() => throw MemosApiException(
      'Cannot reach server',
      cause: DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
      ),
    );

/// Server facade whose behavior the test toggles per call.
class _ScriptedServer extends MemoRepository {
  _ScriptedServer() : super(_account);

  bool online = false;
  final List<String> calls = <String>[];

  void _requireOnline() {
    if (!online) _networkFail();
  }

  @override
  Future<Memo> createMemo({
    required String content,
    required MemoVisibility visibility,
    List<Attachment> attachments = const [],
    String? memoId,
  }) async {
    _requireOnline();
    calls.add('create:$memoId');
    return Memo(
      name: 'memos/${memoId ?? 'srv-1'}',
      content: content,
      visibility: visibility,
      attachments: attachments,
      createTime: DateTime(2026, 1, 1),
    );
  }

  @override
  Future<Memo> updateMemo(Memo memo) async {
    _requireOnline();
    calls.add('update:${memo.uid}');
    throw MemosApiException('bad request', statusCode: 400);
  }

  @override
  Future<void> deleteMemo(String uid) async {
    _requireOnline();
    calls.add('delete:$uid');
  }

  @override
  Future<Memo> getMemo(String uid) async {
    _requireOnline();
    calls.add('get:$uid');
    throw 'unreachable';
  }
}

void main() {
  late AppDatabase db;
  late _ScriptedServer server;
  late CachedMemoRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    server = _ScriptedServer();
    repo = CachedMemoRepository(account: _account, db: db, server: server);
  });

  tearDown(() async {
    await db.close();
  });

  test('createMemo offline queues a pendingCreate row with a local uid',
      () async {
    server.online = false;
    final memo = await repo.createMemo(
        content: 'hello #t', visibility: MemoVisibility.private);

    expect(memo.uid, startsWith('l'));
    expect(server.calls, isEmpty);
    final row = await db.memoDao.getMemo(_account.id, memo.uid);
    expect(row!.syncState, SyncStates.pendingCreate);
    expect(row.memo.content, 'hello #t');
    expect(await repo.isPendingSync(memo.name), isTrue);
  });

  test('createMemo online passes a memoId and hydrates the synced row',
      () async {
    server.online = true;
    final memo = await repo.createMemo(
        content: 'online', visibility: MemoVisibility.private);

    expect(server.calls.single, startsWith('create:l'));
    expect(memo.uid, startsWith('l')); // server echoed our memo_id
    final row = await db.memoDao.getMemo(_account.id, memo.uid);
    expect(row!.syncState, SyncStates.synced);
  });

  test('server errors (4xx) are not treated as offline', () async {
    server.online = true;
    await db.memoDao.upsertLocalMemo(_account.id,
        Memo(name: 'memos/m1', content: 'seed', createTime: DateTime(2026, 1, 1)));
    await expectLater(
      repo.updateMemo(
          Memo(name: 'memos/m1', content: 'x', createTime: DateTime(2026, 1, 1))),
      throwsA(isA<MemosApiException>()),
    );
    // No offline fallback row was written.
    final row = await db.memoDao.getMemo(_account.id, 'm1');
    expect(row!.syncState, SyncStates.synced);
    expect(row.memo.content, 'seed');
  });

  test('updateMemo offline marks pendingUpdate and keeps local content',
      () async {
    await db.memoDao.upsertLocalMemo(
        _account.id,
        Memo(
            name: 'memos/m1',
            content: 'before',
            tags: ['t'],
            createTime: DateTime(2026, 1, 1)));
    server.online = false;

    final updated = await repo.updateMemo(Memo(
        name: 'memos/m1',
        content: 'after',
        pinned: true,
        createTime: DateTime(2026, 1, 1)));

    expect(updated.content, 'after');
    final row = await db.memoDao.getMemo(_account.id, 'm1');
    expect(row!.syncState, SyncStates.pendingUpdate);
    expect(row.memo.pinned, isTrue);
    expect(row.memo.tags, ['t']);
  });

  test('editing a pendingCreate row stays local (no server call)',
      () async {
    server.online = false;
    final memo = await repo.createMemo(
        content: 'v1', visibility: MemoVisibility.private);
    server.calls.clear();

    await repo.updateMemo(Memo(
        name: memo.name,
        content: 'v2',
        visibility: MemoVisibility.private,
        createTime: memo.createTime));

    expect(server.calls, isEmpty);
    final row = await db.memoDao.getMemo(_account.id, memo.uid);
    expect(row!.syncState, SyncStates.pendingCreate);
    expect(row.memo.content, 'v2');
  });

  test('deleting a pendingCreate memo drops it entirely', () async {
    server.online = false;
    final memo = await repo.createMemo(
        content: 'temp', visibility: MemoVisibility.private);

    await repo.deleteMemo(memo.uid);

    expect(await db.memoDao.getMemo(_account.id, memo.uid), isNull);
  });

  test('deleteMemo offline soft-deletes as pendingDelete', () async {
    await db.memoDao.upsertLocalMemo(_account.id,
        Memo(name: 'memos/m1', content: 'seed', createTime: DateTime(2026, 1, 1)));
    server.online = false;

    await repo.deleteMemo('m1');

    final row = await db.memoDao.getMemo(_account.id, 'm1');
    expect(row!.syncState, SyncStates.pendingDelete);
    expect(row.memo.state, MemoState.deleted);
    // The trash query finds it; the home feed doesn't.
    expect((await db.memoDao.readPage(accountId: _account.id, state: 'DELETED'))
        .records
        .map((r) => r.memo.uid),
        ['m1']);
    expect(
        (await db.memoDao.readPage(accountId: _account.id)).records, isEmpty);
  });

  test('uploadAttachment offline queues a local file', () async {
    server.online = false;
    final attachment = await repo.uploadAttachment(
        filename: 'pic.png', mimeType: 'image/png', bytes: [1, 2, 3]);

    expect(attachment.isPendingUpload, isTrue);
    final file = attachment.localPath;
    expect(file, isNotNull);
    expect(await io.File(file!).exists(), isTrue);
    addTearDown(() async {
      try {
        await io.File(file).delete();
      } catch (_) {}
    });

    // Feeding it into an offline create stores it in the queue.
    server.online = false;
    final memo = await repo.createMemo(
      content: 'with pic',
      visibility: MemoVisibility.private,
      attachments: [attachment],
    );
    final queued = await db.memoDao
        .pendingAttachmentsFor(_account.id, memo.uid);
    expect(queued.single.filename, 'pic.png');
    // The row's JSON attachments stay server-known only.
    final row = await db.memoDao.getMemo(_account.id, memo.uid);
    expect(row!.memo.attachments.map((a) => a.name), ['pending/${attachment.uid}']);
  });
}
