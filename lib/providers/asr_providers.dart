import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/asr_repository.dart';

final asrRepositoryProvider =
    Provider<AsrRepository>((ref) => AsrRepository());

/// ASR (speech-to-text) settings, hydrated from secure storage.
/// Mirrors [SettingsNotifier]'s optimistic-default-then-load shape; the
/// epoch guards against a slow hydration load clobbering a save that
/// raced it.
class AsrNotifier extends Notifier<AsrSettings> {
  int _epoch = 0;
  Completer<void>? _hydrate;

  @override
  AsrSettings build() {
    _hydrate = Completer<void>();
    _load(_epoch);
    return const AsrSettings();
  }

  Future<void> _load(int epoch) async {
    var loaded = const AsrSettings();
    try {
      loaded = await ref.read(asrRepositoryProvider).load();
    } catch (_) {
      // A failed storage read keeps the defaults; entry points must still
      // resolve instead of awaiting forever.
    }
    if (epoch == _epoch) state = loaded;
    _settleHydration();
  }

  /// The current settings, but only after the initial storage hydration
  /// (or a save/clear that supersedes it) settles. Action entry points
  /// like voice input must use this instead of a one-shot [asrProvider]
  /// read: on a cold start the optimistic defaults are visible until the
  /// async load lands, which false-triggered the "not configured" prompt.
  Future<AsrSettings> readHydrated() async {
    final pending = _hydrate;
    if (pending != null) await pending.future;
    return state;
  }

  void _settleHydration() {
    final pending = _hydrate;
    _hydrate = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  Future<void> save(AsrSettings settings) async {
    _epoch++;
    _settleHydration();
    state = settings;
    await ref.read(asrRepositoryProvider).save(settings);
  }

  Future<void> clear() async {
    _epoch++;
    _settleHydration();
    state = const AsrSettings();
    await ref.read(asrRepositoryProvider).clear();
  }
}

final asrProvider =
    NotifierProvider<AsrNotifier, AsrSettings>(AsrNotifier.new);
