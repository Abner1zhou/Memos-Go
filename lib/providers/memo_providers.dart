import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  const MemosQuery({this.search, this.tag, this.state});

  final String? search;
  final String? tag;

  /// Memo state wire name to filter by, e.g. `DELETED` for the trash view.
  final String? state;

  @override
  bool operator ==(Object other) => other is MemosQuery &&
      other.search == search &&
      other.tag == tag &&
      other.state == state;

  @override
  int get hashCode => Object.hash(search, tag, state);
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
    final f = buildMemoFilter(query: q.search, tag: q.tag, state: q.state);
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

/// Aggregated account insights for the drawer: recent memos, tag counts and a
/// per-day activity map backing the stats row and heatmap.
class MemoInsights {
  const MemoInsights({
    this.memos = const [],
    this.tagCounts = const {},
    this.dayCounts = const {},
    this.hasMore = false,
    this.oldest,
  });

  final List<Memo> memos;
  final Map<String, int> tagCounts;

  /// `yyyy-MM-dd` (local) -> number of memos created that day.
  final Map<String, int> dayCounts;

  /// True when the aggregation window hit the page cap, i.e. counts are a
  /// lower bound ("500+").
  final bool hasMore;
  final DateTime? oldest;

  int get memoCount => memos.length;
}

/// Single fetch (up to [windowSize] memos) powering drawer stats, the heatmap,
/// daily review and random walk. Invalidate after create/delete mutations.
final memoInsightsProvider =
    FutureProvider.autoDispose<MemoInsights>((ref) async {
  final repo = ref.watch(memoRepositoryProvider);
  if (repo == null) return const MemoInsights();

  const windowSize = 500;
  MemoListPage page;
  try {
    page = await repo.listMemos(pageSize: windowSize);
  } catch (_) {
    // Older servers reject large page sizes; fall back to the default page.
    page = await repo.listMemos();
  }

  final tagCounts = <String, int>{};
  final dayCounts = <String, int>{};
  DateTime? oldest;
  for (final memo in page.memos) {
    for (final tag in memo.tags) {
      tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
    }
    final created = memo.createTime?.toLocal();
    if (created != null) {
      final key =
          '${created.year.toString().padLeft(4, '0')}-'
          '${created.month.toString().padLeft(2, '0')}-'
          '${created.day.toString().padLeft(2, '0')}';
      dayCounts[key] = (dayCounts[key] ?? 0) + 1;
      // List is newest-first, so the last seen date is the oldest.
      oldest = created;
    }
  }
  return MemoInsights(
    memos: page.memos,
    tagCounts: tagCounts,
    dayCounts: dayCounts,
    hasMore: page.nextPageToken.isNotEmpty,
    oldest: oldest,
  );
});

/// Tag names pinned to the top of the drawer, persisted locally.
final pinnedTagsProvider =
    NotifierProvider<PinnedTagsNotifier, List<String>>(PinnedTagsNotifier.new);

class PinnedTagsNotifier extends Notifier<List<String>> {
  static const _prefsKey = 'memos_go.pinned_tags';

  @override
  List<String> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_prefsKey) ?? const [];
  }

  Future<void> toggle(String tag) async {
    state = state.contains(tag)
        ? state.where((t) => t != tag).toList()
        : [...state, tag];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, state);
  }
}
