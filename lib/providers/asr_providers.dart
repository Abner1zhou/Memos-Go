import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/asr_repository.dart';

final asrRepositoryProvider =
    Provider<AsrRepository>((ref) => AsrRepository());

/// ASR (speech-to-text) settings, hydrated from secure storage.
/// Mirrors [SettingsNotifier]'s optimistic-default-then-load shape.
class AsrNotifier extends Notifier<AsrSettings> {
  @override
  AsrSettings build() {
    _load();
    return const AsrSettings();
  }

  Future<void> _load() async {
    state = await ref.read(asrRepositoryProvider).load();
  }

  Future<void> save(AsrSettings settings) async {
    state = settings;
    await ref.read(asrRepositoryProvider).save(settings);
  }

  Future<void> clear() async {
    state = const AsrSettings();
    await ref.read(asrRepositoryProvider).clear();
  }
}

final asrProvider =
    NotifierProvider<AsrNotifier, AsrSettings>(AsrNotifier.new);
