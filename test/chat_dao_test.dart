import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/data/local/app_database.dart';
import 'package:memos_go/data/local/chat_dao.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTests(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('createSession then appendMessage orders by seq and titles session',
      () async {
    final s = await db.chatDao.createSession('acc-1');
    expect(s.title, '');
    expect(s.id, isNotEmpty);

    await db.chatDao.appendMessage('acc-1', s.id,
        role: 'user',
        content: '上个月那个方案我是怎么想的？',
        now: DateTime(2026, 10, 15, 10));
    await db.chatDao.appendMessage('acc-1', s.id,
        role: 'assistant',
        content: '你当时倾向于方案 B [1]',
        sources: const [ChatSource(n: 1, uid: 'memos/a', excerpt: '倾向方案 B')],
        now: DateTime(2026, 10, 15, 10, 0, 1));

    final messages = await db.chatDao.lastMessages('acc-1', s.id, 10);
    expect(messages.map((m) => m.role), ['user', 'assistant']);
    expect(messages.last.parsedSources.single.uid, 'memos/a');
    final sessions = await db.chatDao.watchSessions('acc-1').first;
    expect(sessions.single.title, '上个月那个方案我是怎么想的？');
  });

  test('lastMessages keeps chronology and caps the tail', () async {
    final s = await db.chatDao.createSession('acc-1');
    for (var i = 0; i < 10; i++) {
      await db.chatDao.appendMessage('acc-1', s.id,
          role: 'user', content: 'q$i', now: DateTime(2026, 10, 15, i));
    }
    final tail = await db.chatDao.lastMessages('acc-1', s.id, 3);
    expect(tail.map((m) => m.content), ['q7', 'q8', 'q9']);
  });

  test('deleteSession removes messages too', () async {
    final s = await db.chatDao.createSession('acc-1');
    await db.chatDao.appendMessage('acc-1', s.id,
        role: 'user', content: 'x', now: DateTime(2026, 10, 15));
    await db.chatDao.deleteSession('acc-1', s.id);
    expect(await db.chatDao.lastMessages('acc-1', s.id, 10), isEmpty);
    expect(await db.chatDao.watchSessions('acc-1').first, isEmpty);
  });

  test('sessions are account-scoped and purge wipes them', () async {
    final s = await db.chatDao.createSession('acc-1');
    await db.chatDao.appendMessage('acc-1', s.id,
        role: 'user', content: 'x', now: DateTime(2026, 10, 15));
    expect(await db.chatDao.watchSessions('acc-2').first, isEmpty);

    await db.memoDao.purgeAccount('acc-1');
    expect(await db.chatDao.watchSessions('acc-1').first, isEmpty);
  });

  test('sources json codec roundtrips defensively', () {
    final raw = sourcesToJson(const [
      ChatSource(n: 1, uid: 'memos/a', excerpt: 'e'),
      ChatSource(n: 2, uid: 'memos/b', excerpt: ''),
    ]);
    final back = sourcesFromJson(raw);
    expect(back.length, 2);
    expect(back.first.n, 1);
    expect(back.first.uid, 'memos/a');
    expect(sourcesFromJson('{not json'), isEmpty);
    expect(sourcesFromJson('[{"n": "x", "uid": 3}]'), isEmpty);
  });
}
