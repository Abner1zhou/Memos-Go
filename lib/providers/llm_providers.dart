import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/llm_repository.dart';

final llmRepositoryProvider =
    Provider<LlmRepository>((ref) => LlmRepository());

/// LLM (chat/embeddings) settings, hydrated from secure storage.
/// Mirrors [AsrNotifier]'s optimistic-default-then-load shape; the epoch
/// guards against a slow hydration load clobbering a save that raced it.
class LlmNotifier extends Notifier<LlmSettings> {
  int _epoch = 0;

  @override
  LlmSettings build() {
    _load(_epoch);
    return const LlmSettings();
  }

  Future<void> _load(int epoch) async {
    final loaded = await ref.read(llmRepositoryProvider).load();
    if (epoch != _epoch) return;
    state = loaded;
  }

  Future<void> save(LlmSettings settings) async {
    _epoch++;
    state = settings;
    await ref.read(llmRepositoryProvider).save(settings);
  }

  Future<void> clear() async {
    _epoch++;
    state = const LlmSettings();
    await ref.read(llmRepositoryProvider).clear();
  }
}

final llmProvider =
    NotifierProvider<LlmNotifier, LlmSettings>(LlmNotifier.new);
