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

  @override
  AsrSettings build() {
    _load(_epoch);
    return const AsrSettings();
  }

  Future<void> _load(int epoch) async {
    final loaded = await ref.read(asrRepositoryProvider).load();
    if (epoch != _epoch) return;
    state = loaded;
  }

  Future<void> save(AsrSettings settings) async {
    _epoch++;
    state = settings;
    await ref.read(asrRepositoryProvider).save(settings);
  }

  Future<void> clear() async {
    _epoch++;
    state = const AsrSettings();
    await ref.read(asrRepositoryProvider).clear();
  }
}

final asrProvider =
    NotifierProvider<AsrNotifier, AsrSettings>(AsrNotifier.new);
