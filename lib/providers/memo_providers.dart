import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/formatters.dart';
import '../data/api/memos_api_client.dart';
import '../data/local/memo_dao.dart' show MemoSlice;
import '../data/models/models.dart';
import '../data/repositories/cached_memo_repository.dart';
import '../data/repositories/memo_repository.dart';
import 'auth_providers.dart';
import 'sync_providers.dart';

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
    this.pendingNames = const {},
    this.filter,
    this.tag,
    this.error,
  });

  final MemosListStatus status;
  final List<Memo> memos;
  final String nextPageToken;

  /// Resource names (`memos/{uid}`) whose local edits await a push.
  final Set<String> pendingNames;

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
  static const _pageSize = 50;
  static const _moreToken = 'local';

  StreamSubscription<MemoSlice>? _sliceSub;
  int _limit = _pageSize;

  @override
  MemosListState build(MemosQuery arg) {
    ref.listen<MemoMutation?>(memoMutationProvider, (_, next) {
      if (next != null) _applyMutation(next);
    });
    Future.microtask(() {
      _subscribe();
      refresh();
    });
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

  /// Subscribes to the local mirror for this query. The slice covers rows
  /// `0.._limit`, so paging grows the window and re-emits without gaps.
  void _subscribe() {
    final repo = ref.read(memoRepositoryProvider);
    if (repo is! CachedMemoRepository) return;
    _sliceSub?.cancel();
    _sliceSub = repo
        .watchMemosPage(
          limit: _limit,
          query: arg.search,
          tag: arg.tag,
          state: arg.state,
        )
        .listen((slice) => state = state.copyWith(
              // Keep the initial loading state until anything is on disk.
              status: slice.records.isEmpty &&
                      state.status == MemosListStatus.loading
                  ? MemosListStatus.loading
                  : MemosListStatus.idle,
              memos: slice.records.map((r) => r.memo).toList(),
              pendingNames: slice.records
                  .where((r) => r.isPending)
                  .map((r) => r.memo.name)
                  .toSet(),
              nextPageToken: slice.hasMore ? _moreToken : '',
              error: null,
            ), onError: (e) {
      state = state.copyWith(status: MemosListStatus.error, error: _messageOf(e));
    });
    ref.onDispose(() => _sliceSub?.cancel());
  }

  /// Triggers a server sync; the DB stream updates the list as pages land.
  Future<void> refresh() async {
    state = state.copyWith(status: MemosListStatus.refreshing);
    final engine = ref.read(syncEngineProvider);
    if (engine == null) {
      state = state.copyWith(status: MemosListStatus.idle);
      return;
    }
    // Bound the awaited work so pull-to-refresh spinners don't hang on a
    // slow full pull; late pages still flow in through the stream.
    final ok = await engine
        .sync()
        .timeout(const Duration(seconds: 30), onTimeout: () => false);
    if (!state.status.inFlight) return;
    if (state.memos.isEmpty && !ok) {
      state =
          state.copyWith(status: MemosListStatus.error, error: engine.lastError);
    } else {
      state = state.copyWith(status: MemosListStatus.idle, error: null);
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.status.inFlight) return;
    _limit += _pageSize;
    _subscribe();
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

  void _applyMutation(MemoMutation mutation) {
    switch (mutation) {
      case UpsertMemoMutation(:final memo):
        if (_matchesQuery(memo)) {
          upsertLocal(memo);
        } else {
          removeLocal(memo.name);
        }
      case RemoveMemoMutation(:final name):
        removeLocal(name);
    }
  }

  /// Whether a mutated memo still belongs in this list. Trash lists (state
  /// filter) never take live upserts; tag/search lists match the memo itself,
  /// falling back to content-parsed tags for servers that omit them.
  bool _matchesQuery(Memo memo) {
    if (arg.state != null) return false;
    final tag = arg.tag;
    if (tag != null &&
        !memo.tags.contains(tag) &&
        !extractTags(memo.content).contains(tag)) {
      return false;
    }
    final search = arg.search;
    if (search != null &&
        !memo.content.toLowerCase().contains(search.toLowerCase())) {
      return false;
    }
    return true;
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
    Set<String>? pendingNames,
    String? error,
  }) =>
      MemosListState(
        status: status ?? this.status,
        memos: memos ?? this.memos,
        nextPageToken: nextPageToken ?? this.nextPageToken,
        pendingNames: pendingNames ?? this.pendingNames,
        filter: filter,
        tag: tag,
        error: error,
      );
}

/// A local memo mutation broadcast to every active [memosListProvider]
/// instance, so tag/search views below an editor or card menu stay in sync
/// after create/edit/pin/delete instead of showing stale data.
sealed class MemoMutation {
  const MemoMutation();
}

class UpsertMemoMutation extends MemoMutation {
  const UpsertMemoMutation(this.memo);

  final Memo memo;
}

class RemoveMemoMutation extends MemoMutation {
  const RemoveMemoMutation(this.name);

  final String name;
}

final memoMutationProvider =
    NotifierProvider<MemoMutationNotifier, MemoMutation?>(
        MemoMutationNotifier.new);

class MemoMutationNotifier extends Notifier<MemoMutation?> {
  @override
  MemoMutation? build() => null;

  void upsert(Memo memo) => state = UpsertMemoMutation(memo);

  void remove(String name) => state = RemoveMemoMutation(name);
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

  MemoInsights copyWithHasMore(bool value) =>
      MemoInsights(
        memos: memos,
        tagCounts: tagCounts,
        dayCounts: dayCounts,
        hasMore: value,
        oldest: oldest,
      );
}

/// Aggregated account insights for the drawer: recent memos, tag counts and a
/// per-day activity map backing the stats row and heatmap. Computed from the
/// local mirror so it works offline and recomputes reactively as the sync
/// engine writes; plain server repositories (tests) keep the legacy fetch.
final memoInsightsProvider =
    StreamProvider.autoDispose<MemoInsights>((ref) async* {
  final repo = ref.watch(memoRepositoryProvider);
  if (repo is CachedMemoRepository) {
    await for (final records in repo.watchAllMemos()) {
      yield _aggregateInsights(records.map((r) => r.memo).toList());
    }
    return;
  }
  if (repo == null) {
    yield const MemoInsights();
    return;
  }
  yield await _fetchInsights(repo);
});

/// Folds memos into tag counts, per-day activity and the oldest entry.
MemoInsights _aggregateInsights(List<Memo> memos) {
  final tagCounts = <String, int>{};
  final dayCounts = <String, int>{};
  DateTime? oldest;
  for (final memo in memos) {
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
    memos: memos,
    tagCounts: tagCounts,
    dayCounts: dayCounts,
    // The local mirror holds the full corpus, counts are exact.
    hasMore: false,
    oldest: oldest,
  );
}

Future<MemoInsights> _fetchInsights(MemoRepository repo) async {
  const windowSize = 500;
  MemoListPage page;
  try {
    page = await repo.listMemos(pageSize: windowSize);
  } catch (_) {
    // Older servers reject large page sizes; fall back to the default page.
    page = await repo.listMemos();
  }
  return _aggregateInsights(page.memos).copyWithHasMore(
      page.nextPageToken.isNotEmpty);
}

/// All tags known for the active account as `tag -> memo count`, powering
/// tag autocomplete in the editor. Served from the local mirror (with the
/// content-parsed fallback for servers that omit memo.tags); plain server
/// repositories keep the legacy fetch.
final userTagsProvider =
    StreamProvider.autoDispose<Map<String, int>>((ref) async* {
  final repo = ref.watch(memoRepositoryProvider);
  if (repo is CachedMemoRepository) {
    await for (final records in repo.watchAllMemos()) {
      final counts = <String, int>{};
      for (final record in records) {
        final tags = record.memo.tags.isNotEmpty
            ? record.memo.tags
            : extractTags(record.memo.content).toList();
        for (final tag in tags) {
          counts[tag] = (counts[tag] ?? 0) + 1;
        }
      }
      yield counts;
    }
    return;
  }
  if (repo == null) {
    yield const {};
    return;
  }
  yield await _fetchUserTags(repo);
});

Future<Map<String, int>> _fetchUserTags(MemoRepository repo) async {
  try {
    final stats = await repo.userStats();
    if (stats.tagCounts.isNotEmpty) return stats.tagCounts;
  } catch (_) {
    // Older servers may not expose getStats; fall through.
  }
  try {
    final page = await repo.listMemos(pageSize: 200);
    final counts = <String, int>{};
    for (final memo in page.memos) {
      // Content-parsed fallback for servers that omit memo.tags.
      final tags =
          memo.tags.isNotEmpty ? memo.tags : extractTags(memo.content).toList();
      for (final tag in tags) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    return counts;
  } catch (_) {
    return const {};
  }
}

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
