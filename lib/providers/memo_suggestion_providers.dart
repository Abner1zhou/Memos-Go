import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/app_database.dart';
import '../data/local/memo_codec.dart' show MemoRecord;
import 'auth_providers.dart';
import 'sync_providers.dart' show appDatabaseProvider;

/// The cached suggestion row for one memo uid (null when absent).
final memoSuggestionProvider =
    StreamProvider.autoDispose.family<MemoSuggestionsRow?, String>(
        (ref, uid) {
  final account = ref.watch(authProvider).activeAccount;
  if (account == null) return Stream.value(null);
  return ref
      .watch(appDatabaseProvider)
      .suggestionDao
      .watchSuggestion(account.id, uid);
});

/// The watched memo row for one uid (null when missing), backing the
/// related-memo chips' content excerpt reactively — no imperative query.
final memoWatchProvider =
    StreamProvider.autoDispose.family<MemoRecord?, String>((ref, uid) {
  final account = ref.watch(authProvider).activeAccount;
  if (account == null) return Stream.value(null);
  return ref.watch(appDatabaseProvider).memoDao.watchMemo(account.id, uid);
});
