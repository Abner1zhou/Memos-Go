import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api/memos_api_client.dart';
import '../data/models/models.dart';
import '../data/repositories/memo_repository.dart';
import 'auth_providers.dart';

enum MemosListStatus { idle, loading, loadingMore, refreshing, error }

extension MemosListStatusX on MemosListStatus {
  bool get inFlight => this == MemosListStatus.loading ||
      this == MemosListStatus.refreshing;
}

class MemosListState {
  const MemosListState({
    this.status = MemosListStatus.idle,
    this.memos = const [],
    this.nextPageToken = '',
    this.filter,
    this.tag,
    this.error,
  });

  final MemosListStatus status;
  final List<Memo> memos;
  final String nextPageToken;

  /// CEL filter derived from a search query.
  final String? filter;
  final String? tag;
  final String? error;

  bool get hasMore => nextPageToken.isNotEmpty;
}

/// Paginated memo feed for the given (filter, tag) combination. The family
/// key identifies the tab so switching filters keeps separate caches.
final memosListProvider = NotifierProvider.autoDispose
    .family<MemosListNotifier, MemosListState, MemosQuery>(MemosListNotifier.new);

class MemosQuery {
  const MemosQuery({this.search, this.tag});

  final String? search;
  final String? tag;

  @override
  bool operator ==(Object other) =>
      other is MemosQuery && other.search == search && other.tag == tag;

  @override
  int get hashCode => Object.hash(search, tag);
}

class MemosListNotifier
    extends AutoDisposeFamilyNotifier<MemosListState, MemosQuery> {
  @override
  MemosListState build(MemosQuery arg) {
    Future.microtask(refresh);
    return MemosListState(
      status: MemosListStatus.loading,
      filter: _filterOf(arg),
      tag: arg.tag,
    );
  }

  String? _filterOf(MemosQuery q) {
    final f = buildMemoFilter(query: q.search, tag: q.tag);
    return f.isEmpty ? null : f;
  }

  MemoRepository? get _repo => ref.read(memoRepositoryProvider);

  Future<void> refresh() async {
    final repo = _repo;
    if (repo == null) return;
    state = MemosListState(
      status: MemosListStatus.refreshing,
      filter: _filterOf(arg),
      tag: arg.tag,
    );
    try {
      final page = await repo.listMemos(pageToken: '', filter: state.filter);
      state = state.copyWith(
        status: MemosListStatus.idle,
        memos: page.memos,
        nextPageToken: page.nextPageToken,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
          status: MemosListStatus.error, error: _messageOf(e));
    }
  }

  Future<void> loadMore() async {
    final repo = _repo;
    if (repo == null || !state.hasMore || state.status.inFlight) return;
    state = state.copyWith(status: MemosListStatus.loadingMore);
    try {
      final page =
          await repo.listMemos(pageToken: state.nextPageToken, filter: state.filter);
      state = state.copyWith(
        status: MemosListStatus.idle,
        memos: [...state.memos, ...page.memos],
        nextPageToken: page.nextPageToken,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
          status: MemosListStatus.idle, error: _messageOf(e));
    }
  }

  /// Applies optimistic local changes after a mutation.
  void upsertLocal(Memo memo) {
    final idx = state.memos.indexWhere((m) => m.name == memo.name);
    if (idx >= 0) {
      final next = [...state.memos];
      next[idx] = memo;
      state = state.copyWith(memos: next);
    } else {
      state = state.copyWith(memos: [memo, ...state.memos]);
    }
    _sortLocal();
  }

  void removeLocal(String name) {
    state = state.copyWith(
        memos: state.memos.where((m) => m.name != name).toList());
  }

  void _sortLocal() {
    final sorted = [...state.memos]..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        final at = a.createTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.createTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });
    state = state.copyWith(memos: sorted);
  }
}

extension on MemosListState {
  MemosListState copyWith({
    MemosListStatus? status,
    List<Memo>? memos,
    String? nextPageToken,
    String? error,
  }) =>
      MemosListState(
        status: status ?? this.status,
        memos: memos ?? this.memos,
        nextPageToken: nextPageToken ?? this.nextPageToken,
        filter: filter,
        tag: tag,
        error: error,
      );
}

String _messageOf(Object e) {
  final api = asMemosApiError(e);
  if (api != null) return api.message;
  return e.toString();
}

/// Tag counts for the tags tab; falls back to client-side aggregation from
/// the loaded memo feed when the server rejects the stats call.
final tagCountsProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final repo = ref.watch(memoRepositoryProvider);
  if (repo == null) return {};
  try {
    final stats = await repo.userStats();
    if (stats.tagCounts.isNotEmpty) return stats.tagCounts;
  } catch (_) {
    // fall through to client-side aggregation
  }
  final feed = await repo.listMemos(pageSize: 500);
  final counts = <String, int>{};
  for (final memo in feed.memos) {
    for (final tag in memo.tags) {
      counts[tag] = (counts[tag] ?? 0) + 1;
    }
  }
  return counts;
});
