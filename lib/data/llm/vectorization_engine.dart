import 'dart:async';

import 'package:characters/characters.dart';
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
  }) => VectorizationState(
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
///
/// Request bodies are clipped to [maxInputChars]; blank memos are never
/// sent. A memo the endpoint rejects is skipped: the message lands on
/// [VectorizationState.lastError], vectors already written stay, and the
/// pass continues. Auth, timeout, unreachable, and rate-limit failures
/// stop the pass, as does a batch where every memo fails, so a dead
/// endpoint is not called once per remaining memo. The next trigger (a
/// corpus change, a settings save, or resume) retries what is still stale.
class VectorizationEngine {
  VectorizationEngine({
    required this.accountId,
    required AppDatabase db,
    required this._repository,
  }) : _dao = db.embeddingDao,
       _memoDao = db.memoDao;

  static const batchSize = 16;

  /// Grapheme budget for one embedding input. Compatible endpoints commonly
  /// cap at 8192 tokens (some at 512). 4000 clusters stays under an 8k-token
  /// ceiling for both CJK and Latin, and keeps a long memo from being posted
  /// in full. The stored content hash is still the original text.
  static const maxInputChars = 4000;

  /// Text actually posted for [content], or null when there is nothing to
  /// embed (blank / whitespace only). Oversized memos are clipped to
  /// [maxInputChars] grapheme clusters and are not given an ellipsis.
  static String? embeddingInput(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return null;
    final chars = trimmed.characters;
    if (chars.length <= maxInputChars) return trimmed;
    return chars.take(maxInputChars).toString();
  }

  final String accountId;
  final EmbeddingDao _dao;
  final MemoDao _memoDao;
  final LlmRepository _repository;

  final state = ValueNotifier<VectorizationState>(const VectorizationState());

  bool _running = false;
  bool _paused = false;
  // Bumped by clearVectors and abandonInFlight so an in-flight pass stops
  // instead of resurrecting rows a wipe just deleted.
  int _generation = 0;
  Timer? _debounce;
  StreamSubscription<void>? _corpusSub;

  /// Subscribes to corpus changes (any memo write lands there after sync)
  /// and kicks off an initial pass. Tests that call [run] directly skip
  /// this to stay timer-free.
  void start() {
    _corpusSub = _watchCorpus().listen((_) => schedule());
    schedule();
  }

  Stream<void> _watchCorpus() => _memoDao.watchAll(accountId).map<void>((_) {});

  /// Debounced pass request, e.g. after a sync wrote new memos.
  void schedule({Duration delay = const Duration(seconds: 4)}) {
    _debounce?.cancel();
    _debounce = Timer(delay, run);
  }

  /// Runs one pass. Never throws; failures land in [state].
  Future<void> run() async {
    if (_running || _paused) return;
    _running = true;
    // Declared outside try so the catch can see a wipe that landed mid-pass.
    final generation = _generation;
    try {
      final settings = await _repository.load();
      final model = settings.embeddingModel.trim();
      if (!settings.embeddingsConfigured) {
        _state(const VectorizationState());
        return;
      }

      final corpus = await _dao.corpus(accountId);
      final hashes = await _dao.embeddedHashes(accountId, model);
      // A pause/clear landing during the initial awaits must win over the
      // running status this pass is about to publish.
      if (_paused || generation != _generation) return;
      final pending = <_PendingEmbed>[];
      final skipped = <String>[];
      for (final memo in corpus) {
        final input = embeddingInput(memo.content);
        if (input == null) {
          skipped.add(memo.uid);
          continue;
        }
        if (hashes[memo.uid] != stableHash(memo.content)) {
          pending.add(_PendingEmbed(memo, input));
        }
      }
      if (skipped.isNotEmpty) {
        await _dao.deleteForUids(accountId, skipped);
        if (_paused || generation != _generation) return;
      }
      // Blank memos are not embeddable, so they stay out of the progress
      // total instead of sitting forever as "not yet vectorized".
      final total = corpus.length - skipped.length;
      var done = total - pending.length;
      _state(
        VectorizationState(
          status: VectorStatus.running,
          embedded: done,
          total: total,
        ),
      );

      String? passError;
      for (var i = 0; i < pending.length; i += batchSize) {
        if (_paused || generation != _generation) return;
        final batch = pending.skip(i).take(batchSize).toList();
        final outcome = await _embedBatch(
          settings: settings,
          model: model,
          batch: batch,
          generation: generation,
        );
        // clearVectors owns the notifier after a generation bump; don't
        // republish progress on top of the wiped state.
        if (generation != _generation) return;
        done += outcome.embedded;
        if (outcome.message != null) passError = outcome.message;
        if (outcome.embedded > 0 || outcome.message != null) {
          _state(
            state.value.copyWith(embedded: done, lastError: outcome.message),
          );
        }
        if (_paused) return;
        if (outcome.halt) break;
      }

      if (_paused || generation != _generation) return;
      if (passError != null) {
        _state(
          state.value.copyWith(
            status: VectorStatus.error,
            embedded: done,
            total: total,
            lastError: passError,
          ),
        );
        return;
      }

      await _dao.deleteOrphans(accountId);
      // A completed pass makes the current model the only source of truth;
      // rows of previously used models are dead weight (the 3-column PK
      // keeps them around otherwise). Partial failures skip this so a model
      // switch doesn't drop the previous index before the new one is whole.
      await _dao.deleteOtherModels(accountId, model);
      if (_paused || generation != _generation) return;
      _state(
        VectorizationState(
          status: VectorStatus.idle,
          embedded: total,
          total: total,
        ),
      );
    } catch (e) {
      // A pause or privacy wipe that landed during this pass owns the
      // notifier; don't overwrite it with an error from the abandoned work.
      if (_paused || generation != _generation) return;
      // Last resort: settings/corpus reads must never crash the caller.
      _state(
        state.value.copyWith(
          status: VectorStatus.error,
          lastError: e.toString(),
        ),
      );
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
    _state(
      state.value.copyWith(status: VectorStatus.running, clearError: true),
    );
    schedule(delay: Duration.zero);
  }

  /// Wipes the account's vectors and resets progress. Any in-flight pass is
  /// stopped (it must not re-write the rows just deleted) and stays paused;
  /// a fresh pass needs [resume], a settings save, or a corpus change.
  Future<void> clearVectors() async {
    _debounce?.cancel();
    _generation++;
    _paused = true;
    await _dao.deleteAllForAccount(accountId);
    _state(const VectorizationState(status: VectorStatus.paused));
  }

  /// Stops a debounced or in-flight pass so it cannot write vectors after a
  /// privacy wipe. Unlike [clearVectors], this does not pause later passes
  /// and does not delete rows (the wipe deletes every account).
  void abandonInFlight() {
    _debounce?.cancel();
    _generation++;
    if (!_paused) {
      _state(const VectorizationState());
    }
  }

  Future<void> dispose() async {
    _debounce?.cancel();
    await _corpusSub?.cancel();
  }

  void _state(VectorizationState next) => state.value = next;

  /// Embeds [batch]. A rejected memo is retried alone so its siblings can
  /// still be stored. The outcome's halt flag is set when continuing would
  /// only repeat a broken call: auth, timeout, unreachable, HTTP 429, or
  /// every item in the batch failed.
  Future<_BatchOutcome> _embedBatch({
    required LlmSettings settings,
    required String model,
    required List<_PendingEmbed> batch,
    required int generation,
  }) async {
    final inputs = [for (final item in batch) item.input];
    final whole = await _tryEmbed(settings, inputs);
    // A clear landing mid-request must not resurrect the rows it deleted.
    if (generation != _generation) return const _BatchOutcome();
    if (whole.vectors != null && whole.vectors!.length == batch.length) {
      await _persist(model, [
        for (var j = 0; j < batch.length; j++)
          _write(batch[j], whole.vectors![j]),
      ]);
      return _BatchOutcome(embedded: batch.length);
    }

    final batchError =
        whole.error ??
        LlmApiException(
          'Embedding count mismatch: ${whole.vectors?.length ?? 0} of ${batch.length}',
        );
    // A single-item batch is already isolated. Systemic failures won't
    // succeed per memo, so don't fan out into one request per memo.
    if (_haltsPass(batchError) || batch.length == 1) {
      return _BatchOutcome(
        message: _failureText(batchError),
        halt: _haltsPass(batchError),
      );
    }

    var embedded = 0;
    String? message;
    for (final item in batch) {
      if (_paused || generation != _generation) {
        return _BatchOutcome(embedded: embedded, message: message);
      }
      final one = await _tryEmbed(settings, [item.input]);
      if (generation != _generation) {
        return _BatchOutcome(embedded: embedded, message: message);
      }
      if (one.vectors != null && one.vectors!.length == 1) {
        await _persist(model, [_write(item, one.vectors!.first)]);
        embedded += 1;
        continue;
      }
      final error =
          one.error ??
          LlmApiException(
            'Embedding count mismatch: ${one.vectors?.length ?? 0} of 1',
          );
      message = _failureText(error);
      if (_haltsPass(error)) {
        return _BatchOutcome(embedded: embedded, message: message, halt: true);
      }
    }
    return _BatchOutcome(
      embedded: embedded,
      message: message,
      halt: message != null && embedded == 0,
    );
  }

  Future<_EmbedCall> _tryEmbed(
    LlmSettings settings,
    List<String> inputs,
  ) async {
    try {
      return _EmbedCall.ok(
        await _repository.embeddings(settings, inputs: inputs),
      );
    } catch (e) {
      return _EmbedCall.fail(e);
    }
  }

  Future<void> _persist(String model, List<EmbeddingWrite> rows) =>
      _dao.upsertAll(accountId, model, rows);

  EmbeddingWrite _write(_PendingEmbed item, List<double> vector) =>
      EmbeddingWrite(
        uid: item.memo.uid,
        contentHash: stableHash(item.memo.content),
        vector: Float32List.fromList(vector),
      );

  bool _haltsPass(Object error) {
    if (error is! LlmApiException) return false;
    if (error.statusCode == 429) return true;
    return switch (error.kind) {
      LlmErrorKind.auth ||
      LlmErrorKind.timeout ||
      LlmErrorKind.unreachable => true,
      _ => false,
    };
  }

  String _failureText(Object error) =>
      error is LlmApiException ? error.message : error.toString();
}

class _PendingEmbed {
  const _PendingEmbed(this.memo, this.input);

  final EmbeddableMemo memo;
  final String input;
}

class _EmbedCall {
  const _EmbedCall.ok(this.vectors) : error = null;
  const _EmbedCall.fail(this.error) : vectors = null;

  final List<List<double>>? vectors;
  final Object? error;
}

class _BatchOutcome {
  const _BatchOutcome({this.embedded = 0, this.message, this.halt = false});

  final int embedded;
  final String? message;

  /// Stop the pass. Successes already in [embedded] stay written.
  final bool halt;
}
