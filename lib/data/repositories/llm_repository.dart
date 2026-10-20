import 'dart:convert' as convert;

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/llm_api.dart';

/// Configured LLM (chat + embeddings) endpoint. Persists as one JSON blob in
/// secure storage because it contains the API key.
class LlmSettings {
  const LlmSettings({
    this.baseUrl = '',
    this.apiKey = '',
    this.chatModel = '',
    this.embeddingModel = '',
  });

  /// OpenAI-compatible endpoint base, e.g. `https://api.deepseek.com/v1`.
  final String baseUrl;
  final String apiKey;
  final String chatModel;

  /// Optional for P1; required once P2 (vector search) lands.
  final String embeddingModel;

  bool get isConfigured =>
      baseUrl.trim().isNotEmpty &&
      apiKey.isNotEmpty &&
      chatModel.trim().isNotEmpty;

  bool get embeddingsConfigured =>
      isConfigured && embeddingModel.trim().isNotEmpty;

  LlmSettings copyWith({
    String? baseUrl,
    String? apiKey,
    String? chatModel,
    String? embeddingModel,
  }) =>
      LlmSettings(
        baseUrl: baseUrl ?? this.baseUrl,
        apiKey: apiKey ?? this.apiKey,
        chatModel: chatModel ?? this.chatModel,
        embeddingModel: embeddingModel ?? this.embeddingModel,
      );

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'chatModel': chatModel,
        'embeddingModel': embeddingModel,
      };

  /// Tolerates non-string fields: they coerce to '' instead of throwing, so
  /// one bad field cannot wipe out the rest of the saved config.
  static String _asString(Object? value) => value is String ? value : '';

  factory LlmSettings.fromJson(Map<String, dynamic> json) => LlmSettings(
        baseUrl: _asString(json['baseUrl']),
        apiKey: _asString(json['apiKey']),
        chatModel: _asString(json['chatModel']),
        embeddingModel: _asString(json['embeddingModel']),
      );
}

/// Persists [LlmSettings] and runs chat completions / embeddings against the
/// configured OpenAI-compatible endpoint.
class LlmRepository {
  LlmRepository({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'memos_go.llmConfig';

  final FlutterSecureStorage _storage;

  Dio? _dio;
  (String, String)? _dioKey;

  /// Reuses one Dio per (baseUrl, apiKey); rebuilt only when the endpoint
  /// config changes so P2's batch embedding loops keep connections warm.
  Dio _dioFor(LlmSettings settings) {
    final key = (normalizeLlmBaseUrl(settings.baseUrl), settings.apiKey);
    if (_dio == null || _dioKey != key) {
      _dio = createLlmDio(baseUrl: key.$1, apiKey: key.$2);
      _dioKey = key;
    }
    return _dio!;
  }

  /// Loads the saved settings; corrupt or missing data yields defaults.
  Future<LlmSettings> load() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) return const LlmSettings();
    try {
      final json = convert.jsonDecode(raw);
      if (json is Map) return LlmSettings.fromJson(json.cast<String, dynamic>());
    } catch (_) {
      // Fall through to defaults on corrupt JSON.
    }
    return const LlmSettings();
  }

  Future<void> save(LlmSettings settings) => _storage.write(
        key: _storageKey,
        value: convert.jsonEncode(settings.toJson()),
      );

  Future<void> clear() => _storage.delete(key: _storageKey);

  Future<String> chat(
    LlmSettings settings, {
    required List<LlmChatMessage> messages,
    int? maxTokens,
  }) {
    final dio = _dioFor(settings);
    return LlmApi(dio).chat(
      model: settings.chatModel.trim(),
      messages: messages,
      maxTokens: maxTokens,
    );
  }

  /// Streaming variant of [chat] for the RAG conversation page.
  Stream<String> chatStream(
    LlmSettings settings, {
    required List<LlmChatMessage> messages,
    int? maxTokens,
  }) {
    final dio = _dioFor(settings);
    return LlmApi(dio).chatStream(
      model: settings.chatModel.trim(),
      messages: messages,
      maxTokens: maxTokens,
    );
  }

  Future<List<List<double>>> embeddings(
    LlmSettings settings, {
    required List<String> inputs,
  }) {
    final dio = _dioFor(settings);
    return LlmApi(dio).embeddings(
      model: settings.embeddingModel.trim(),
      inputs: inputs,
    );
  }
}
