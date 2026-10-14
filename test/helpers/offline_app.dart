import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:memos_go/data/api/memos_api_client.dart';
import 'package:memos_go/data/local/app_database.dart';
import 'package:memos_go/data/models/models.dart';
import 'package:memos_go/data/repositories/auth_repository.dart';
import 'package:memos_go/data/repositories/cached_memo_repository.dart';
import 'package:memos_go/data/repositories/memo_repository.dart';
import 'package:memos_go/providers/sync_providers.dart';

/// The stub account used across widget tests. The id doubles as the
/// accountId keys in seeded databases.
final testAccount = ServerAccount(
  id: 'http://x|tester',
  baseUrl: 'http://127.0.0.1:9',
  token: 'tok',
  user: const User(name: 'users/1', username: 'tester'),
);

/// A server facade whose every call fails like an unreachable network, so
/// widget tests hit the offline fallback paths deterministically (the test
/// binding otherwise fakes HTTP with 400 responses, which are not network
/// failures).
class UnreachableServer extends MemoRepository {
  UnreachableServer() : super(testAccount);

  Never _fail() => throw MemosApiException(
        'Cannot reach server',
        cause: DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionError,
        ),
      );

  @override
  Future<MemoListPage> listMemos({
    int pageSize = 50,
    String pageToken = '',
    String? filter,
  }) async => _fail();

  @override
  Future<Memo> getMemo(String uid) async => _fail();

  @override
  Future<Memo> createMemo({
    required String content,
    required MemoVisibility visibility,
    List<Attachment> attachments = const [],
    String? memoId,
  }) async => _fail();

  @override
  Future<Memo> updateMemo(Memo memo) async => _fail();

  @override
  Future<void> deleteMemo(String uid) async => _fail();

  @override
  Future<UserStats> userStats() async => _fail();
}

/// Builds an in-memory database pre-seeded with [normal] and [deleted]
/// memos for [accountId], ready to back [appDatabaseProvider] overrides.
Future<AppDatabase> buildSeededDb({
  List<Memo> normal = const [],
  List<Memo> deleted = const [],
  String accountId = 'http://x|tester',
}) async {
  final db = AppDatabase.forTests(NativeDatabase.memory());
  for (final memo in normal) {
    await db.memoDao.upsertLocalMemo(accountId, memo);
  }
  for (final memo in deleted) {
    await db.memoDao.upsertLocalMemo(accountId, memo);
  }
  return db;
}

/// Overrides that give a test the real DB-backed data path (repository,
/// streams) without any sync engine or connectivity plugin involvement.
/// Server calls go to an unreachable facade so offline fallbacks run.
/// The database intentionally leaks (no onDispose close): drift's close
/// schedules zero-delay timers that would otherwise trip the test
/// binding's "timers pending" invariant during teardown.
List<Override> offlineTestOverrides(AppDatabase db) => [
      appDatabaseProvider.overrideWithValue(db),
      syncEngineProvider.overrideWithValue(null),
    ];

CachedMemoRepository offlineRepo(AppDatabase db) => CachedMemoRepository(
      account: testAccount,
      db: db,
      server: UnreachableServer(),
    );

/// Memo factory used across widget tests.
Memo testMemo(
  String uid,
  String content, {
  DateTime? created,
  List<String> tags = const [],
  MemoState state = MemoState.normal,
  List<Attachment> attachments = const [],
  bool pinned = false,
}) =>
    Memo(
      name: 'memos/$uid',
      state: state,
      content: content,
      tags: tags,
      pinned: pinned,
      attachments: attachments,
      createTime: created ?? DateTime.now(),
    );
