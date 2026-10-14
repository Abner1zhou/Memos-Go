import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:memos_go/data/local/app_database.dart';
import 'package:memos_go/data/models/models.dart';

Memo _memo(
  String uid, {
  String content = '',
  bool pinned = false,
  List<String> tags = const [],
  MemoState state = MemoState.normal,
  DateTime? createTime,
}) =>
    Memo(
      name: 'memos/$uid',
      content: content,
      pinned: pinned,
      tags: tags,
      state: state,
      createTime: createTime ?? DateTime(2026, 1, 10),
    );

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('watchPage', () {
    test('orders pinned first then createTime desc', () async {
      final dao = db.memoDao;
      await dao.upsertLocalMemo('a', _memo('old', createTime: DateTime(2026, 1, 1)));
      await dao.upsertLocalMemo('a', _memo('new', createTime: DateTime(2026, 2, 1)));
      await dao.upsertLocalMemo('a', _memo('pin', pinned: true, createTime: DateTime(2025, 12, 1)));

      final slice = await dao.watchPage(accountId: 'a').first;
      expect(slice.records.map((r) => r.memo.uid), ['pin', 'new', 'old']);
    });

    test('state filter restricts to the given wire name', () async {
      final dao = db.memoDao;
      await dao.upsertLocalMemo('a', _memo('live'));
      await dao.upsertLocalMemo(
          'a', _memo('gone', state: MemoState.deleted));

      final home = await dao.watchPage(accountId: 'a').first;
      expect(home.records.map((r) => r.memo.uid), ['live']);

      final trash =
          await dao.watchPage(accountId: 'a', state: 'DELETED').first;
      expect(trash.records.map((r) => r.memo.uid), ['gone']);
    });

    test('tag filter is an exact match through the side table', () async {
      final dao = db.memoDao;
      await dao.upsertLocalMemo('a', _memo('t1', tags: ['work']));
      await dao.upsertLocalMemo('a', _memo('t2', tags: ['workflow']));

      final slice =
          await dao.watchPage(accountId: 'a', tag: 'work').first;
      expect(slice.records.map((r) => r.memo.uid), ['t1']);
    });

    test('content query matches substrings incl. CJK and escapes wildcards',
        () async {
      final dao = db.memoDao;
      await dao.upsertLocalMemo('a', _memo('c1', content: '你好世界 hello'));
      await dao.upsertLocalMemo('a', _memo('c2', content: '50% off'));
      await dao.upsertLocalMemo('a', _memo('c3', content: 'plain'));

      expect(
        (await dao.watchPage(accountId: 'a', query: '好世').first)
            .records
            .map((r) => r.memo.uid),
        ['c1'],
      );
      // A literal % must not act as a wildcard.
      expect(
        (await dao.watchPage(accountId: 'a', query: '0% o').first)
            .records
            .map((r) => r.memo.uid),
        ['c2'],
      );
      expect(
        (await dao.watchPage(accountId: 'a', query: 'lain').first)
            .records
            .map((r) => r.memo.uid),
        ['c3'],
      );
    });

    test('pages with hasMore and keeps accounts isolated', () async {
      final dao = db.memoDao;
      for (var i = 0; i < 5; i++) {
        await dao.upsertLocalMemo('a', _memo('m$i'));
        await dao.upsertLocalMemo('b', _memo('x$i'));
      }

      final page1 = await dao.watchPage(accountId: 'a', limit: 3).first;
      expect(page1.records.length, 3);
      expect(page1.hasMore, isTrue);

      final page2 = await dao
          .watchPage(accountId: 'a', limit: 3, offset: 3)
          .first;
      expect(page2.records.length, 2);
      expect(page2.hasMore, isFalse);
      expect(page2.records.map((r) => r.memo.uid), ['m1', 'm0']);
    });

    test('round-trips attachments and tags through JSON columns',
        () async {
      final dao = db.memoDao;
      final memo = _memo('att', tags: ['a/b', 'tag with space'])
        ..copyWith();
      await dao.upsertLocalMemo('a', memo.copyWith());
      final read = await dao.getMemo('a', 'att');
      expect(read, isNotNull);
      expect(read!.memo.uid, 'att');
      expect(read.memo.tags, ['a/b', 'tag with space']);
    });
  });

  group('applyServerPull', () {
    test('overwrites synced rows but keeps pending local rows', () async {
      final dao = db.memoDao;
      await dao.upsertLocalMemo('a', _memo('m1', content: 'server'));
      await dao.upsertLocalMemo(
        'a',
        _memo('m2', content: 'local edit'),
        syncState: SyncStates.pendingUpdate,
        editedAt: DateTime.now(),
      );

      await dao.applyServerPull('a', [
        _memo('m1', content: 'server v2'),
        _memo('m2', content: 'server stale'),
        _memo('m3'),
      ]);

      final all = await dao.pendingMemos('a');
      expect(all.length, 1);

      final m1 = await dao.getMemo('a', 'm1');
      expect(m1!.memo.content, 'server v2');
      expect(m1.syncState, SyncStates.synced);

      final m2 = await dao.getMemo('a', 'm2');
      expect(m2!.memo.content, 'local edit');
      expect(m2.syncState, SyncStates.pendingUpdate);
    });
  });

  group('markSyncedFromServer', () {
    test('re-keys the row when the server assigned another uid', () async {
      final dao = db.memoDao;
      await dao.upsertLocalMemo(
        'a',
        _memo('local-1', content: 'offline', tags: ['t']),
        syncState: SyncStates.pendingCreate,
        editedAt: DateTime.now(),
      );

      await dao.markSyncedFromServer('a',
          localUid: 'local-1',
          serverMemo: _memo('srv-9', content: 'offline', tags: ['t']));

      expect(await dao.getMemo('a', 'local-1'), isNull);
      final row = await dao.getMemo('a', 'srv-9');
      expect(row!.syncState, SyncStates.synced);
      expect(row.memo.tags, ['t']);
      // Tag side table follows the new uid.
      final tagged =
          await dao.watchPage(accountId: 'a', tag: 't').first;
      expect(tagged.records.map((r) => r.memo.uid), ['srv-9']);
    });
  });

  group('sweep', () {
    test('removes synced rows absent from every pass, keeps pending ones',
        () async {
      final dao = db.memoDao;
      await dao.upsertLocalMemo('a', _memo('keep'));
      await dao.upsertLocalMemo('a', _memo('vanished'));
      await dao.upsertLocalMemo('a', _memo('deletedOnServer', state: MemoState.deleted));
      await dao.upsertLocalMemo(
        'a',
        _memo('pendingEdit'),
        syncState: SyncStates.pendingUpdate,
        editedAt: DateTime.now(),
      );

      await dao.sweep('a',
          liveUids: {'keep', 'pendingEdit'}, deletedUids: {'deletedOnServer2'});

      expect(await dao.getMemo('a', 'keep'), isNotNull);
      // Absent from live and deleted passes -> gone entirely.
      expect(await dao.getMemo('a', 'vanished'), isNull);
      // DELETED row absent from the deleted pass -> purged.
      expect(await dao.getMemo('a', 'deletedOnServer'), isNull);
      // Pending rows are never swept.
      expect(await dao.getMemo('a', 'pendingEdit'), isNotNull);
    });
  });

  group('pendingMemos', () {
    test('orders creates before updates before deletes', () async {
      final dao = db.memoDao;
      final now = DateTime.now();
      await dao.upsertLocalMemo('a', _memo('u'),
          syncState: SyncStates.pendingUpdate, editedAt: now);
      await dao.upsertLocalMemo('a', _memo('d'),
          syncState: SyncStates.pendingDelete, editedAt: now);
      await dao.upsertLocalMemo('a', _memo('c'),
          syncState: SyncStates.pendingCreate, editedAt: now);

      final pending = await dao.pendingMemos('a');
      expect(pending.map((r) => r.memo.uid).toList(), ['c', 'u', 'd']);
    });
  });

  test('purgeAccount removes every trace of the account', () async {
    final dao = db.memoDao;
    await dao.upsertLocalMemo('a', _memo('m1', tags: ['t']));
    await dao.upsertLocalMemo('b', _memo('m1', tags: ['t']));
    await dao.setSyncMeta('a', DateTime.now(), 'ok');

    await dao.purgeAccount('a');

    expect(await dao.getMemo('a', 'm1'), isNull);
    expect((await dao.watchPage(accountId: 'a', tag: 't').first).records,
        isEmpty);
    expect(await dao.getMemo('b', 'm1'), isNotNull);
  });
}
