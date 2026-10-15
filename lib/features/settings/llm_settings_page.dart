import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/llm_errors.dart';
import '../../data/api/llm_api.dart';
import '../../data/llm/vectorization_engine.dart';
import '../../data/repositories/llm_repository.dart';
import '../../providers/llm_providers.dart';
import '../../providers/vectorization_providers.dart';

/// Configures an OpenAI-compatible LLM endpoint (chat + embeddings) for AI
/// features like the daily review digest.
class LlmSettingsPage extends ConsumerStatefulWidget {
  const LlmSettingsPage({super.key});

  @override
  ConsumerState<LlmSettingsPage> createState() => _LlmSettingsPageState();
}

class _LlmSettingsPageState extends ConsumerState<LlmSettingsPage> {
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _chatModelController = TextEditingController();
  final _embeddingModelController = TextEditingController();

  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final settings = await ref.read(llmRepositoryProvider).load();
      if (!mounted) return;
      _baseUrlController.text = settings.baseUrl;
      _apiKeyController.text = settings.apiKey;
      _chatModelController.text = settings.chatModel;
      _embeddingModelController.text = settings.embeddingModel;
    });
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _chatModelController.dispose();
    _embeddingModelController.dispose();
    super.dispose();
  }

  LlmSettings _currentFields() => LlmSettings(
        baseUrl: normalizeLlmBaseUrl(_baseUrlController.text.trim()),
        apiKey: _apiKeyController.text.trim(),
        chatModel: _chatModelController.text.trim(),
        embeddingModel: _embeddingModelController.text.trim(),
      );

  /// Returns the settings to persist, or null (with `_error` set) when the
  /// form is invalid. An entirely empty form is allowed and simply disables
  /// AI features.
  LlmSettings? _validate() {
    final l10n = AppLocalizations.of(context)!;
    final settings = _currentFields();
    final empty = settings.baseUrl.isEmpty &&
        settings.apiKey.isEmpty &&
        settings.chatModel.isEmpty;
    if (empty) return settings;
    if (llmBaseUrlInvalid(settings.baseUrl)) {
      setState(() => _error = l10n.llmInvalidBaseUrl);
      return null;
    }
    return settings;
  }

  /// Pings the chat endpoint with a tiny completion, then (when an embedding
  /// model is set) the embeddings endpoint, surfacing each result.
  Future<void> _test() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _error = null);
    final settings = _validate();
    if (settings == null) return;
    if (!settings.isConfigured) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(llmRepositoryProvider);
    try {
      await repo.chat(
        settings,
        messages: const [LlmChatMessage(role: 'user', content: 'ping')],
        maxTokens: 8,
      );
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.llmTestOk)));
      if (settings.embeddingsConfigured) {
        await repo.embeddings(settings, inputs: const ['你好', 'hello']);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.llmEmbeddingsTestOk)));
      }
    } on LlmApiException catch (e) {
      setState(() => _error = '${l10n.llmTestFailed}: ${llmErrorMessage(l10n, e)}');
    } catch (e) {
      setState(() => _error = '${l10n.llmTestFailed}: ${llmErrorMessage(l10n, e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() => _error = null);
    final settings = _validate();
    if (settings == null) return;
    await ref.read(llmProvider.notifier).save(settings);
    if (mounted && context.canPop()) context.pop();
  }

  Future<void> _clear() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l10n.llmClearConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(llmProvider.notifier).clear();
    if (!mounted) return;
    setState(() {
      _baseUrlController.clear();
      _apiKeyController.clear();
      _chatModelController.clear();
      _embeddingModelController.clear();
      _error = null;
    });
  }

  Future<void> _clearVectors(
      BuildContext context, VectorizationEngine? engine) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l10n.vecClearConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed == true) await engine?.clearVectors();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final configured = ref.watch(llmProvider).isConfigured;
    final engine = ref.watch(vectorizationEngineProvider);
    final vec = ref.watch(vectorizationStateProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.llmSettingsTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          Text(
            l10n.llmSettingsSubtitle,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _baseUrlController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.llmBaseUrl,
              hintText: l10n.llmBaseUrlHint,
              prefixIcon: const Icon(Icons.dns_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _apiKeyController,
            autocorrect: false,
            obscureText: true,
            decoration: InputDecoration(
              labelText: l10n.llmApiKey,
              prefixIcon: const Icon(Icons.key_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _chatModelController,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.llmChatModel,
              hintText: l10n.llmChatModelHint,
              prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _embeddingModelController,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.llmEmbeddingModel,
              hintText: l10n.llmEmbeddingModelHint,
              prefixIcon: const Icon(Icons.blur_on_outlined),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.save),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : _test,
            child: Text(l10n.llmTest),
          ),
          if (configured) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : _clear,
              child: Text(l10n.llmClear,
                  style: TextStyle(color: theme.colorScheme.error)),
            ),
          ],
          if (ref.watch(llmProvider).embeddingsConfigured) ...[
            const Divider(height: 32),
            Text(l10n.vecSection,
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.primary)),
            const SizedBox(height: 4),
            Text(
              l10n.vecPrivacyNote,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            if (vec != null && vec.total > 0) ...[
              LinearProgressIndicator(value: vec.fraction),
              const SizedBox(height: 4),
              Text(l10n.vecProgress(vec.embedded, vec.total),
                  style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 4),
            Row(children: [
              TextButton(
                onPressed: () => vec?.status == VectorStatus.paused
                    ? engine?.resume()
                    : engine?.pause(),
                child: Text(vec?.status == VectorStatus.paused
                    ? l10n.vecResume
                    : l10n.vecPause),
              ),
              TextButton(
                onPressed: () => _clearVectors(context, engine),
                child: Text(l10n.vecClear,
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}
