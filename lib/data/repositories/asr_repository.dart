import 'dart:convert' as convert;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/asr_api.dart';

/// Configured ASR (speech-to-text) model. Persists as one JSON blob in
/// secure storage because it contains the API key.
class AsrSettings {
  const AsrSettings({
    this.dialect = AsrDialect.openai,
    this.baseUrl = '',
    this.apiKey = '',
    this.model = '',
    this.language = '',
    this.keepAudio = true,
  });

  /// Wire dialect of the configured service.
  final AsrDialect dialect;

  /// OpenAI-compatible endpoint base, e.g. `https://api.openai.com/v1`
  /// or DashScope's `https://dashscope.aliyuncs.com/compatible-mode/v1`.
  final String baseUrl;
  final String apiKey;
  final String model;

  /// ISO code hint sent with each request; empty = auto-detect.
  final String language;

  /// Attach the recorded audio to the memo after transcription.
  final bool keepAudio;

  bool get isConfigured =>
      baseUrl.trim().isNotEmpty && apiKey.isNotEmpty && model.trim().isNotEmpty;

  AsrSettings copyWith({
    AsrDialect? dialect,
    String? baseUrl,
    String? apiKey,
    String? model,
    String? language,
    bool? keepAudio,
  }) =>
      AsrSettings(
        dialect: dialect ?? this.dialect,
        baseUrl: baseUrl ?? this.baseUrl,
        apiKey: apiKey ?? this.apiKey,
        model: model ?? this.model,
        language: language ?? this.language,
        keepAudio: keepAudio ?? this.keepAudio,
      );

  Map<String, dynamic> toJson() => {
        'dialect': dialect.name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        'language': language,
        'keepAudio': keepAudio,
      };

  factory AsrSettings.fromJson(Map<String, dynamic> json) => AsrSettings(
        dialect: asrDialectFromName(json['dialect'] as String?),
        baseUrl: json['baseUrl'] as String? ?? '',
        apiKey: json['apiKey'] as String? ?? '',
        model: json['model'] as String? ?? '',
        language: json['language'] as String? ?? '',
        keepAudio: json['keepAudio'] as bool? ?? true,
      );
}

/// Persists [AsrSettings] and runs transcriptions against the configured
/// OpenAI-compatible endpoint.
class AsrRepository {
  AsrRepository({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'memos_go.asrConfig';

  final FlutterSecureStorage _storage;

  /// Loads the saved settings; corrupt or missing data yields defaults.
  Future<AsrSettings> load() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) return const AsrSettings();
    try {
      final json = convert.jsonDecode(raw);
      if (json is Map) return AsrSettings.fromJson(json.cast<String, dynamic>());
    } catch (_) {
      // Fall through to defaults on corrupt JSON.
    }
    return const AsrSettings();
  }

  Future<void> save(AsrSettings settings) => _storage.write(
        key: _storageKey,
        value: convert.jsonEncode(settings.toJson()),
      );

  Future<void> clear() => _storage.delete(key: _storageKey);

  /// Transcribes [bytes] with [settings]; [mimeType] must match the audio
  /// container so the endpoint can decode the upload.
  Future<String> transcribe(
    AsrSettings settings, {
    required List<int> bytes,
    required String filename,
    String mimeType = 'audio/mp4',
  }) {
    final dio = createAsrDio(
      baseUrl: normalizeAsrBaseUrl(settings.baseUrl, dialect: settings.dialect),
      apiKey: settings.apiKey,
    );
    return AsrApi(dio).transcribe(
      model: settings.model.trim(),
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
      language: settings.language.trim(),
      dialect: settings.dialect,
    );
  }
}
