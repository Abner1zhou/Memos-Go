import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/utils/stable_hash.dart';
import '../api/llm_api.dart';
import '../local/app_database.dart';
import '../local/embedding_dao.dart';
import '../local/memo_dao.dart';
import '../repositories/llm_repository.dart';

enum VectorStatus { idle, running, paused, error }

class VectorizationState {
  const VectorizationState({
    this.status = VectorStatus.idle,
    this.embedded = 0,
    this.total = 0,
    this.lastError,
  });

  final VectorStatus status;
  final int embedded;
  final int total;
  final String? lastError;

  double? get fraction =>
      total == 0 ? null : (embedded / total).clamp(0.0, 1.0);

  VectorizationState copyWith({
    VectorStatus? status,
    int? embedded,
    int? total,
    String? lastError,
    bool clearError = false,
  }) =>
      VectorizationState(
        status: status ?? this.status,
        embedded: embedded ?? this.embedded,
        total: total ?? this.total,
        lastError: clearError ? null : (lastError ?? this.lastError),
      );
}

/// Incrementally embeds the account's corpus against the configured
/// OpenAI-compatible endpoint. The embedding table itself is the resume
/// state: a pass embeds whatever's missing or hash-stale in batches of
/// [batchSize], so interruptions (app kill, pause, error) lose nothing.
/// Errors stop the pass instead of retry-storming; the next trigger (a
/// corpus change via watchAll, a settings save, or resume) retries.
class VectorizationEngine {
  VectorizationEngine({
    required this.accountId,
    required AppDatabase db,
    required this._repository,
  })  : _dao = db.embeddingDao,
        _memoDao = db.memoDao;

  static const batchSize = 16;

  final String accountId;
  final EmbeddingDao _dao;
  final MemoDao _memoDao;
  final LlmRepository _repository;

  final state = ValueNotifier<VectorizationState>(const VectorizationState());

  bool _running = false;
  bool _paused = false;
  Timer? _debounce;
  StreamSubscription<void>? _corpusSub;

  /// Subscribes to corpus changes (any memo write lands there after sync)
  /// and kicks off an initial pass. Tests that call [run] directly skip
  /// this to stay timer-free.
  void start() {
    _corpusSub = _watchCorpus().listen((_) => schedule());
    schedule();
  }

  Stream<void> _watchCorpus() =>
      _memoDao.watchAll(accountId).map<void>((_) {});

  /// Debounced pass request, e.g. after a sync wrote new memos.
  void schedule({Duration delay = const Duration(seconds: 4)}) {
    _debounce?.cancel();
    _debounce = Timer(delay, run);
  }

  /// Runs one pass. Never throws; failures land in [state].
  Future<void> run() async {
    if (_running || _paused) return;
    _running = true;
    try {
      final settings = await _repository.load();
      final model = settings.embeddingModel.trim();
      if (!settings.embeddingsConfigured) {
        _state(const VectorizationState());
        return;
      }

      final corpus = await _dao.corpus(accountId);
      final hashes = await _dao.embeddedHashes(accountId, model);
      final pending = <EmbeddableMemo>[
        for (final m in corpus)
          if (hashes[m.uid] != stableHash(m.content)) m
      ];
      var done = corpus.length - pending.length;
      _state(VectorizationState(
          status: VectorStatus.running,
          embedded: done,
          total: corpus.length));

      for (var i = 0; i < pending.length; i += batchSize) {
        if (_paused) return;
        final batch = pending.skip(i).take(batchSize).toList();
        try {
          final vectors = await _repository.embeddings(
              settings,
              inputs: [for (final m in batch) m.content]);
          if (vectors.length != batch.length) {
            throw LlmApiException(
                'Embedding count mismatch: ${vectors.length} of ${batch.length}');
          }
          await _dao.upsertAll(accountId, model, [
            for (var j = 0; j < batch.length; j++)
              EmbeddingWrite(
                  uid: batch[j].uid,
                  contentHash: stableHash(batch[j].content),
                  vector: Float32List.fromList(vectors[j])),
          ]);
        } on LlmApiException catch (e) {
          _state(state.value.copyWith(
              status: VectorStatus.error, lastError: e.message));
          return;
        } catch (e) {
          _state(state.value.copyWith(
              status: VectorStatus.error, lastError: e.toString()));
          return;
        }
        done += batch.length;
        _state(state.value.copyWith(embedded: done));
      }

      await _dao.deleteOrphans(accountId);
      // A completed pass makes the current model the only source of truth;
      // rows of previously used models are dead weight (the 3-column PK
      // keeps them around otherwise).
      await _dao.deleteOtherModels(accountId, model);
      _state(VectorizationState(
          status: VectorStatus.idle,
          embedded: corpus.length,
          total: corpus.length));
    } finally {
      _running = false;
    }
  }

  void pause() {
    _paused = true;
    _debounce?.cancel();
    _state(state.value.copyWith(status: VectorStatus.paused));
  }

  void resume() {
    _paused = false;
    _state(state.value.copyWith(
        status: VectorStatus.running, clearError: true));
    schedule(delay: Duration.zero);
  }

  /// Wipes the account's vectors and resets progress. A fresh pass needs a
  /// new trigger (settings save, corpus change, or resume).
  Future<void> clearVectors() async {
    _debounce?.cancel();
    await _dao.deleteAllForAccount(accountId);
    _state(const VectorizationState());
  }

  Future<void> dispose() async {
    _debounce?.cancel();
    await _corpusSub?.cancel();
  }

  void _state(VectorizationState next) => state.value = next;
}
