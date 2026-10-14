import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/app_database.dart';
import '../data/repositories/cached_memo_repository.dart';
import '../data/repositories/memo_repository.dart';
import '../data/sync/sync_engine.dart';
import 'auth_providers.dart';

/// The on-disk local mirror, opened lazily and shared by every provider.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

/// The sync engine bound to the active account (null while signed out).
final syncEngineProvider = Provider<SyncEngine?>((ref) {
  final account = ref.watch(authProvider).activeAccount;
  if (account == null) return null;
  final engine = SyncEngine(
    accountId: account.id,
    server: MemoRepository(account),
    db: ref.watch(appDatabaseProvider),
  );
  engine.start();
  ref.onDispose(engine.dispose);
  return engine;
});

/// Whether any transport is up, from the OS's point of view. The engine
/// still discovers real reachability by trying; this only gates eager
/// retries and drives the offline banner.
final onlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  yield await connectivity
      .checkConnectivity()
      .then((results) => results.any((r) => r != ConnectivityResult.none));
  yield* connectivity.onConnectivityChanged.map(
      (results) => results.any((r) => r != ConnectivityResult.none));
});

final _pendingCountProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(memoRepositoryProvider);
  return repo is CachedMemoRepository
      ? repo.watchPendingCount()
      : Stream.value(0);
});

final _syncMetaProvider = StreamProvider<SyncMetaRow>((ref) {
  final repo = ref.watch(memoRepositoryProvider);
  return repo is CachedMemoRepository
      ? repo.watchSyncMeta()
      : Stream.value(const SyncMetaRow(accountId: '', lastResult: ''));
});

final _enginePhaseProvider = StreamProvider<SyncPhase>((ref) {
  final engine = ref.watch(syncEngineProvider);
  if (engine == null) return Stream.value(SyncPhase.idle);
  final controller = StreamController<SyncPhase>();
  void listener() => controller.add(engine.phase.value);
  engine.phase.addListener(listener);
  controller.onCancel = () {
    engine.phase.removeListener(listener);
    controller.close();
  };
  return controller.stream;
});

/// What the sync indicator UI shows.
class SyncStatusState {
  const SyncStatusState({
    this.phase = SyncPhase.idle,
    this.pendingCount = 0,
    this.online = true,
    this.everSynced = false,
  });

  final SyncPhase phase;
  final int pendingCount;
  final bool online;

  /// Whether the local mirror has completed a sync at least once.
  final bool everSynced;

  bool get syncing => phase != SyncPhase.idle;
}

/// Composite sync status: engine phase + pending queue + connectivity +
/// sync meta, recomputed whenever any of them changes.
final syncStatusProvider = Provider<SyncStatusState>((ref) {
  final phase = ref.watch(_enginePhaseProvider).value ?? SyncPhase.idle;
  final pendingCount = ref.watch(_pendingCountProvider).value ?? 0;
  final online = ref.watch(onlineProvider).value ?? true;
  final meta = ref.watch(_syncMetaProvider).value;
  return SyncStatusState(
    phase: phase,
    pendingCount: pendingCount,
    online: online,
    everSynced: meta != null && meta.lastResult == 'ok',
  );
});
