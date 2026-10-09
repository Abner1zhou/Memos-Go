import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/data/models/models.dart';
import 'package:memos_go/data/repositories/auth_repository.dart';
import 'package:memos_go/data/repositories/memo_repository.dart';
import 'package:memos_go/providers/auth_providers.dart';
import 'package:memos_go/providers/memo_providers.dart';

/// Emulates the server-side CEL filtering this app generates, so tag/search
/// instances see the same data they would from the real ListMemos endpoint.
class _FakeRepo extends MemoRepository {
  _FakeRepo(this._memos)
      : super(ServerAccount(
          id: 'http://x|tester',
          baseUrl: 'http://x',
          token: 'tok',
          user: const User(name: 'users/1', username: 'tester'),
        ));

  final List<Memo> _memos;

  @override
  Future<MemoListPage> listMemos({
    int pageSize = 50,
    String pageToken = '',
    String? filter,
  }) async {
    await Future<void>.delayed(Duration.zero);
    final tagMatch = RegExp(r'"((?:[^"\\]|\\.)*)" in tags').firstMatch(filter ?? '');
    final searchMatch =
        RegExp(r'content.contains\("((?:[^"\\]|\\.)*)"\)').firstMatch(filter ?? '');
    final memos = _memos.where((m) {
      if (tagMatch != null) return m.tags.contains(tagMatch.group(1));
      if (searchMatch != null) {
        return m.content
            .toLowerCase()
            .contains(searchMatch.group(1)!.toLowerCase());
      }
      return true;
    }).toList();
    return MemoListPage(memos: memos);
  }
}

Memo _memo(String uid, String content, {List<String> tags = const []}) => Memo(
      name: 'memos/$uid',
      content: content,
      tags: tags,
      createTime: DateTime(2026, 1, 1),
    );

void main() {
  test('memo mutations broadcast to every active list instance', () async {
    final memos = [
      _memo('a', 'first #work', tags: ['work']),
      _memo('b', 'second #life', tags: ['life']),
    ];
    final container = ProviderContainer(overrides: [
      memoRepositoryProvider.overrideWith((ref) => _FakeRepo(memos)),
    ]);
    addTearDown(container.dispose);

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
    final container = ProviderContainer(overrides: [
      memoRepositoryProvider.overrideWith((ref) => _FakeRepo([])),
    ]);
    addTearDown(container.dispose);

    final trash = container.listen(
        memosListProvider(const MemosQuery(state: 'DELETED')), (_, _) {});
    await pumpEventQueue();

    container
        .read(memoMutationProvider.notifier)
        .upsert(_memo('x', 'alive #work', tags: ['work']));
    expect(trash.read().memos, isEmpty);
  });
}
