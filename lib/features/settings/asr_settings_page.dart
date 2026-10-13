import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/api/asr_api.dart';
import '../../data/repositories/asr_repository.dart';
import '../../providers/asr_providers.dart';

/// Configures an OpenAI-compatible speech-to-text model for voice input.
class AsrSettingsPage extends ConsumerStatefulWidget {
  const AsrSettingsPage({super.key});

  @override
  ConsumerState<AsrSettingsPage> createState() => _AsrSettingsPageState();
}

class _AsrSettingsPageState extends ConsumerState<AsrSettingsPage> {
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  final _languageController = TextEditingController();

  var _dialect = AsrDialect.openai;
  var _keepAudio = true;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final settings = await ref.read(asrRepositoryProvider).load();
      if (!mounted) return;
      _baseUrlController.text = settings.baseUrl;
      _apiKeyController.text = settings.apiKey;
      _modelController.text = settings.model;
      _languageController.text = settings.language;
      setState(() {
        _dialect = settings.dialect;
        _keepAudio = settings.keepAudio;
      });
    });
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _languageController.dispose();
    super.dispose();
  }

  AsrSettings _currentFields() => AsrSettings(
        dialect: _dialect,
        baseUrl:
            normalizeAsrBaseUrl(_baseUrlController.text.trim(), dialect: _dialect),
        apiKey: _apiKeyController.text.trim(),
        model: _modelController.text.trim(),
        language: _languageController.text.trim(),
        keepAudio: _keepAudio,
      );

  /// Returns the settings to persist, or null (with `_error` set) when the
  /// form is invalid. An entirely empty form is allowed and simply disables
  /// voice input.
  AsrSettings? _validate() {
    final l10n = AppLocalizations.of(context)!;
    final settings = _currentFields();
    final empty = settings.baseUrl.isEmpty &&
        settings.apiKey.isEmpty &&
        settings.model.isEmpty;
    if (empty) return settings;
    if (asrBaseUrlInvalid(settings.baseUrl)) {
      setState(() => _error = l10n.asrInvalidBaseUrl);
      return null;
    }
    return settings;
  }

  Future<void> _test() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _error = null);
    final settings = _validate();
    if (settings == null) return;
    if (!settings.isConfigured) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(asrRepositoryProvider).transcribe(
            settings,
            bytes: silentWav(),
            filename: 'test.wav',
            mimeType: 'audio/wav',
          );
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.asrTestOk)));
    } on AsrApiException catch (e) {
      setState(() => _error = '${l10n.transcribeFailed}: ${e.message}');
    } catch (e) {
      setState(() => _error = '${l10n.transcribeFailed}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() => _error = null);
    final settings = _validate();
    if (settings == null) return;
    await ref.read(asrProvider.notifier).save(settings);
    if (mounted && context.canPop()) context.pop();
  }

  Future<void> _clear() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l10n.asrClearConfirm),
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
    await ref.read(asrProvider.notifier).clear();
    if (!mounted) return;
    setState(() {
      _dialect = AsrDialect.openai;
      _baseUrlController.clear();
      _apiKeyController.clear();
      _modelController.clear();
      _languageController.clear();
      _keepAudio = true;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final configured = ref.watch(asrProvider).isConfigured;
    final (baseHint, modelHint, note) = switch (_dialect) {
      AsrDialect.dashscope => (
        l10n.asrDashscopeBaseUrlHint,
        l10n.asrDashscopeModelHint,
        l10n.asrDashscopeNote,
      ),
      AsrDialect.dashscopeNative => (
        l10n.asrDashscopeNativeBaseUrlHint,
        l10n.asrDashscopeModelHint,
        l10n.asrDashscopeNativeNote,
      ),
      AsrDialect.openai => (
        l10n.asrBaseUrlHint,
        l10n.asrModelHint,
        null,
      ),
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.asrSettingsTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          Text(
            l10n.asrSettingsSubtitle,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (kIsWeb) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 18, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.asrWebCorsNote,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          SegmentedButton<AsrDialect>(
            selected: {_dialect},
            onSelectionChanged: (s) => setState(() => _dialect = s.first),
            segments: [
              ButtonSegment(
                value: AsrDialect.openai,
                label: Text(l10n.asrDialectOpenai,
                    style: const TextStyle(fontSize: 12)),
              ),
              ButtonSegment(
                value: AsrDialect.dashscope,
                label: Text(l10n.asrDialectDashscope,
                    style: const TextStyle(fontSize: 12)),
              ),
              ButtonSegment(
                value: AsrDialect.dashscopeNative,
                label: Text(l10n.asrDialectDashscopeNative,
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(
              note,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _baseUrlController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.asrBaseUrl,
              hintText: baseHint,
              prefixIcon: const Icon(Icons.dns_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _apiKeyController,
            autocorrect: false,
            obscureText: true,
            decoration: InputDecoration(
              labelText: l10n.asrApiKey,
              prefixIcon: const Icon(Icons.key_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _modelController,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.asrModel,
              hintText: modelHint,
              prefixIcon: const Icon(Icons.graphic_eq_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _languageController,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.asrLanguage,
              hintText: l10n.asrLanguageHint,
              prefixIcon: const Icon(Icons.translate_rounded),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _keepAudio,
            onChanged: (v) => setState(() => _keepAudio = v),
            title: Text(l10n.asrKeepAudio),
            subtitle: Text(l10n.asrKeepAudioSubtitle),
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
            child: Text(l10n.asrTest),
          ),
          if (configured) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : _clear,
              child: Text(l10n.asrClear,
                  style: TextStyle(color: theme.colorScheme.error)),
            ),
          ],
        ],
      ),
    );
  }
}
