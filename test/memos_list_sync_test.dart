import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/data/models/models.dart';
import 'package:memos_go/providers/auth_providers.dart';
import 'package:memos_go/providers/memo_providers.dart';

import 'helpers/offline_app.dart';

Memo _memo(String uid, String content, {List<String> tags = const []}) => Memo(
      name: 'memos/$uid',
      content: content,
      tags: tags,
      createTime: DateTime(2026, 1, 1),
    );

Future<ProviderContainer> _container(List<Memo> memos) async {
  final db = await buildSeededDb(normal: memos);
  final container = ProviderContainer(overrides: [
    memoRepositoryProvider.overrideWith((ref) => offlineRepo(db)),
    ...offlineTestOverrides(db),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('memo mutations broadcast to every active list instance', () async {
    final container = await _container([
      _memo('a', 'first #work', tags: ['work']),
      _memo('b', 'second #life', tags: ['life']),
    ]);

    // Keep subscriptions so the autoDispose family instances stay alive,
    // exactly like a tag page sitting below an open editor.
    final home = container.listen(
        memosListProvider(const MemosQuery()), (_, _) {});
    final work = container.listen(
        memosListProvider(const MemosQuery(tag: 'work')), (_, _) {});
    await pumpEventQueue();

    expect(home.read().memos.map((m) => m.uid), containsAll(['a', 'b']));
    expect(work.read().memos.map((m) => m.uid), ['a']);

    // Create a memo tagged #work from the tag page's composer: it lands in
    // both the home feed and the tag list.
    container
        .read(memoMutationProvider.notifier)
        .upsert(_memo('c', 'new #work', tags: ['work']));
    expect(home.read().memos.first.uid, 'c');
    expect(work.read().memos.map((m) => m.uid), contains('c'));

    // Edit it to drop the tag: it leaves the tag list but stays in home.
    container.read(memoMutationProvider.notifier).upsert(_memo('c', 'new'));
    expect(home.read().memos.map((m) => m.uid), contains('c'));
    expect(work.read().memos.map((m) => m.uid), isNot(contains('c')));

    // Servers that omit the tags field on the response still match through
    // content-parsed tags.
    container
        .read(memoMutationProvider.notifier)
        .upsert(_memo('d', 'fallback #work'));
    expect(work.read().memos.map((m) => m.uid), contains('d'));

    // Delete broadcasts removal everywhere.
    container.read(memoMutationProvider.notifier).remove('memos/a');
    expect(home.read().memos.map((m) => m.uid), isNot(contains('a')));
    expect(work.read().memos.map((m) => m.uid), isNot(contains('a')));
  });

  test('trash lists ignore upsert broadcasts', () async {
    final container = await _container([]);

    final trash = container.listen(
        memosListProvider(const MemosQuery(state: 'DELETED')), (_, _) {});
    await pumpEventQueue();

    container
        .read(memoMutationProvider.notifier)
        .upsert(_memo('x', 'alive #work', tags: ['work']));
    expect(trash.read().memos, isEmpty);
  });
}
