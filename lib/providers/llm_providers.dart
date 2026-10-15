import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/llm_repository.dart';

final llmRepositoryProvider =
    Provider<LlmRepository>((ref) => LlmRepository());

/// LLM (chat/embeddings) settings, hydrated from secure storage.
/// Mirrors [AsrNotifier]'s optimistic-default-then-load shape.
class LlmNotifier extends Notifier<LlmSettings> {
  @override
  LlmSettings build() {
    _load();
    return const LlmSettings();
  }

  Future<void> _load() async {
    state = await ref.read(llmRepositoryProvider).load();
  }

  Future<void> save(LlmSettings settings) async {
    state = settings;
    await ref.read(llmRepositoryProvider).save(settings);
  }

  Future<void> clear() async {
    state = const LlmSettings();
    await ref.read(llmRepositoryProvider).clear();
  }
}

final llmProvider =
    NotifierProvider<LlmNotifier, LlmSettings>(LlmNotifier.new);
