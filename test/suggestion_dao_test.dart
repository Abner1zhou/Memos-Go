import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/data/local/app_database.dart';
import 'package:memos_go/data/local/suggestion_dao.dart';
import 'package:memos_go/data/models/models.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTests(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedMemo(String uid,
      {String content = 'x', List<String> tags = const []}) async {
    await db.memoDao.upsertLocalMemo('acc-1', Memo(
        name: 'memos/$uid',
        content: content,
        tags: tags,
        createTime: DateTime(2026, 10, 20)));
  }

  test('upsert then watchSuggestion emits the row; re-upsert replaces',
      () async {
    await seedMemo('a');
    await db.suggestionDao.upsert('acc-1', 'a',
        contentHash: 1,
        suggestion: const MemoSuggestion(
            tags: ['运维', 'k8s'], relatedUids: ['memos/b']),
        now: DateTime(2026, 10, 20));
    final row = await db.suggestionDao.watchSuggestion('acc-1', 'a').first;
    expect(row!.tagList, ['运维', 'k8s']);
    expect(row.relatedUidList, ['memos/b']);
    expect(row.contentHash, 1);

    await db.suggestionDao.upsert('acc-1', 'a',
        contentHash: 2,
        suggestion: const MemoSuggestion(tags: [], relatedUids: []),
        now: DateTime(2026, 10, 20));
    final again = await db.suggestionDao.watchSuggestion('acc-1', 'a').first;
    expect(again!.contentHash, 2);
    expect(again.tagList, isEmpty);
  });

  test('account scoping: another account sees nothing', () async {
    await seedMemo('a');
    await db.suggestionDao.upsert('acc-1', 'a',
        contentHash: 1,
        suggestion: const MemoSuggestion(tags: ['t'], relatedUids: []),
        now: DateTime(2026, 10, 20));
    expect(await db.suggestionDao.watchSuggestion('acc-2', 'a').first, isNull);
  });

  test('distinctTags returns sorted unique tags of the account', () async {
    await seedMemo('a', tags: ['运维', 'k8s']);
    await seedMemo('b', tags: ['运维']);
    // acc-2's tags must not leak into acc-1's distinct list.
    await db.memoDao.upsertLocalMemo('acc-2', Memo(
        name: 'memos/acc2-only',
        content: 'y',
        tags: ['只属于二'],
        createTime: DateTime(2026, 10, 20)));
    expect(await db.suggestionDao.distinctTags('acc-1'),
        ['k8s', '运维']);
  });

  test('memo delete paths cascade to suggestions', () async {
    await seedMemo('a');
    await db.suggestionDao.upsert('acc-1', 'a',
        contentHash: 1,
        suggestion: const MemoSuggestion(tags: [], relatedUids: []),
        now: DateTime(2026, 10, 20));
    await db.memoDao.deleteLocalMemo('acc-1', 'a');
    expect(await db.suggestionDao.watchSuggestion('acc-1', 'a').first, isNull);
  });

  test('sweep clears suggestions of removed synced memos', () async {
    await seedMemo('a');
    await db.suggestionDao.upsert('acc-1', 'a',
        contentHash: 1,
        suggestion: const MemoSuggestion(tags: [], relatedUids: []),
        now: DateTime(2026, 10, 20));
    await db.memoDao
        .sweep('acc-1', liveUids: const {}, deletedUids: const {});
    expect(await db.suggestionDao.watchSuggestion('acc-1', 'a').first, isNull);
  });

  test('purge wipes suggestions', () async {
    await seedMemo('a');
    await db.suggestionDao.upsert('acc-1', 'a',
        contentHash: 1,
        suggestion: const MemoSuggestion(tags: [], relatedUids: []),
        now: DateTime(2026, 10, 20));
    await db.memoDao.purgeAccount('acc-1');
    expect(await db.suggestionDao.watchSuggestion('acc-1', 'a').first, isNull);
  });

  test('suggestion codec is defensive', () {
    final json = suggestionToJson(
        const MemoSuggestion(tags: ['a'], relatedUids: ['memos/x']));
    expect(json, contains('memos/x'));
    expect(suggestionFromJson(json)!.tags, ['a']);
    expect(suggestionFromJson('{not json'), isNull);
    expect(suggestionFromJson('{"tags": 3}'), isNull);
  });
}
