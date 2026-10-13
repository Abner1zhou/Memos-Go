import 'dart:convert' as convert;
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Wire dialect for the configured ASR service.
enum AsrDialect {
  /// `POST {base}/audio/transcriptions` with multipart audio
  /// (OpenAI, Groq, SiliconFlow, local whisper.cpp, ...).
  openai,

  /// `POST {base}/chat/completions` with the recording inlined as a
  /// base64 Data URL `input_audio` part and the transcript read from
  /// `choices[0].message.content`. DashScope (阿里云百炼) exposes its ASR
  /// this way; only the qwen3-asr-flash model series supports it and each
  /// recording must stay under 5 minutes / 10 MB.
  dashscope,

  /// DashScope *native* protocol:
  /// `POST {host}/api/v1/services/aigc/multimodal-generation/generation`
  /// with `input.messages` + a plain `audio` content entry and the
  /// transcript under `output.choices[0].message.content[].text`. Same
  /// qwen3-asr-flash models and 5-minute limit as [dashscope].
  dashscopeNative,
}

/// Defensive parse of a persisted dialect name; unknown values fall back to
/// the OpenAI-compatible dialect.
AsrDialect asrDialectFromName(String? name) =>
    AsrDialect.values.where((d) => d.name == name).firstOrNull ??
    AsrDialect.openai;

/// Typed error surfaced by the ASR layer so UI can show friendly messages.
class AsrApiException implements Exception {
  const AsrApiException(this.message, {this.statusCode, this.cause});

  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => 'AsrApiException($statusCode): $message';
}

/// Normalizes a user-entered OpenAI-compatible endpoint: adds https:// when
/// the scheme is missing and strips trailing slashes.
///
/// Per dialect: DashScope compatible-mode rewrites a trailing `/api/v1`
/// (the DashScope *native* protocol prefix, easy to copy from the console)
/// to `/compatible-mode/v1`; the DashScope native dialect collapses any
/// `/api/v1` or `/compatible-mode/v1` suffix to the host root because the
/// full `/api/v1/services/...` path is appended by the client.
String normalizeAsrBaseUrl(String raw, {AsrDialect dialect = AsrDialect.openai}) {
  var url = raw.trim();
  if (url.isEmpty) return url;
  if (!url.startsWith(RegExp(r'https?://'))) url = 'https://$url';
  url = url.replaceAll(RegExp(r'/+$'), '');
  switch (dialect) {
    case AsrDialect.openai:
      break;
    case AsrDialect.dashscope:
      url = url.replaceFirst(RegExp(r'/api/v1$'), '/compatible-mode/v1');
    case AsrDialect.dashscopeNative:
      url = url.replaceFirst(RegExp(r'/api/v1$'), '');
      url = url.replaceFirst(RegExp(r'/compatible-mode/v1$'), '');
  }
  return url;
}

/// Returns whether [raw] fails to parse as an endpoint URL (scheme + host,
/// no spaces) for the caller to map to a localized message.
bool asrBaseUrlInvalid(String raw) {
  final url = normalizeAsrBaseUrl(raw);
  if (url.isEmpty || RegExp(r'\s').hasMatch(url)) return true;
  final uri = Uri.tryParse(url);
  return uri == null || !uri.hasScheme || uri.host.isEmpty;
}

/// Creates a [Dio] client pointed at an OpenAI-compatible endpoint base
/// (e.g. `https://api.openai.com/v1`). [apiKey] is sent as
/// `Authorization: Bearer` on every request.
Dio createAsrDio({required String baseUrl, required String apiKey}) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    // Transcribing a long recording can take a while on slower services.
    receiveTimeout: const Duration(minutes: 2),
    sendTimeout: const Duration(seconds: 60),
    headers: {
      'Authorization': 'Bearer $apiKey',
    },
  ));
  dio.interceptors.add(InterceptorsWrapper(
    onError: (e, handler) {
      handler.reject(
        DioException(
          requestOptions: e.requestOptions,
          error: AsrApiException(
            _asrMessageOf(e),
            statusCode: e.response?.statusCode,
            cause: e,
          ),
          type: e.type,
          response: e.response,
        ),
      );
    },
  ));
  return dio;
}

/// OpenAI-style errors use `{"error": {"message": ...}}`; some compatible
/// servers answer `{"message": ...}` instead. Both are honored. The
/// fallback always carries the HTTP status (or the underlying socket/TLS
/// error) so a bare gateway answer like an empty 404 stays diagnosable.
String _asrMessageOf(DioException e) {
  final data = e.response?.data;
  if (data is Map) {
    final error = data['error'];
    if (error is Map) {
      final msg = error['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
    final msg = data['message'];
    if (msg is String && msg.isNotEmpty) return msg;
  }
  final detail = switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
      'Connection timed out',
    DioExceptionType.connectionError => 'Cannot reach server',
    DioExceptionType.unknown => e.error?.toString() ?? 'Request failed',
    _ => e.response?.statusMessage ?? e.message ?? 'Request failed',
  };
  final status = e.response?.statusCode;
  return status == null ? detail : 'HTTP $status $detail';
}

/// Extracts an [AsrApiException] from a thrown object, if any.
AsrApiException? asAsrApiError(Object error) {
  if (error is AsrApiException) return error;
  if (error is DioException) {
    final inner = error.error;
    if (inner is AsrApiException) return inner;
  }
  return null;
}

/// Client for an OpenAI-compatible speech-to-text endpoint. The wire format
/// depends on [AsrDialect]: multipart `/audio/transcriptions` or DashScope's
/// chat-completions `input_audio` variant.
class AsrApi {
  AsrApi(this.dio);

  final Dio dio;

  /// Sends [bytes] as audio and returns the transcribed text (empty string
  /// when the service returns no text).
  Future<String> transcribe({
    required String model,
    required List<int> bytes,
    required String filename,
    String mimeType = 'audio/mp4',
    String? language,
    AsrDialect dialect = AsrDialect.openai,
  }) async {
    try {
      final data = switch (dialect) {
        AsrDialect.openai => await _postOpenai(
            model: model,
            bytes: bytes,
            filename: filename,
            mimeType: mimeType,
            language: language),
        AsrDialect.dashscope => await _postDashscope(
            model: model,
            bytes: bytes,
            mimeType: mimeType,
            language: language),
        AsrDialect.dashscopeNative => await _postDashscopeNative(
            model: model,
            bytes: bytes,
            mimeType: mimeType,
            language: language),
      };
      return _extractText(data, dialect);
    } on AsrApiException {
      rethrow;
    } on DioException catch (e) {
      final inner = e.error;
      if (inner is AsrApiException) throw inner;
      throw AsrApiException(_asrMessageOf(e), cause: e);
    }
  }

  Future<Map<String, dynamic>> _postOpenai({
    required String model,
    required List<int> bytes,
    required String filename,
    required String mimeType,
    String? language,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes,
          filename: filename, contentType: DioMediaType.parse(mimeType)),
      'model': model,
      if (language != null && language.isNotEmpty) 'language': language,
    });
    final res = await dio.post<Map<dynamic, dynamic>>(
      '/audio/transcriptions',
      data: form,
    );
    return (res.data ?? const {}).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> _postDashscope({
    required String model,
    required List<int> bytes,
    required String mimeType,
    String? language,
  }) async {
    final res = await dio.post<Map<dynamic, dynamic>>(
      '/chat/completions',
      data: {
        'model': model,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'input_audio',
                'input_audio': {
                  // DashScope accepts a base64 Data URL for local audio.
                  'data': 'data:$mimeType;base64,${convert.base64Encode(bytes)}',
                },
              },
            ],
          },
        ],
        'asr_options': {
          if (language != null && language.isNotEmpty) 'language': language,
          // Inverse text normalization ("二零二六" -> "2026"), nicer for memos.
          'enable_itn': true,
        },
      },
    );
    return (res.data ?? const {}).cast<String, dynamic>();
  }

  /// DashScope native protocol: `input.messages` with a plain `audio`
  /// content entry and `parameters.asr_options` (distinct from the
  /// OpenAI-style top-level `messages` of the compatible mode).
  Future<Map<String, dynamic>> _postDashscopeNative({
    required String model,
    required List<int> bytes,
    required String mimeType,
    String? language,
  }) async {
    final res = await dio.post<Map<dynamic, dynamic>>(
      '/api/v1/services/aigc/multimodal-generation/generation',
      data: {
        'model': model,
        'input': {
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  // Native mode accepts a base64 Data URL for local audio.
                  'audio': 'data:$mimeType;base64,${convert.base64Encode(bytes)}',
                },
              ],
            },
          ],
        },
        'parameters': {
          'asr_options': {
            if (language != null && language.isNotEmpty) 'language': language,
            // Inverse text normalization ("二零二六" -> "2026"), nicer for memos.
            'enable_itn': true,
          },
        },
      },
    );
    return (res.data ?? const {}).cast<String, dynamic>();
  }

  static String _extractText(Map<String, dynamic> data, AsrDialect dialect) =>
      switch (dialect) {
        AsrDialect.openai => data['text'] as String? ?? '',
        AsrDialect.dashscope => _chatChoicesText(data),
        AsrDialect.dashscopeNative => _nativeOutputText(data),
      };

  /// `choices[0].message.content` is a plain string in compatible mode.
  static String _chatChoicesText(Map<String, dynamic> data) {
    final choices = data['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map) {
        final msg = first['message'];
        if (msg is Map) return msg['content'] as String? ?? '';
      }
    }
    return '';
  }

  /// `output.choices[0].message.content` is a list of `{text: ...}` parts
  /// in the native protocol.
  static String _nativeOutputText(Map<String, dynamic> data) {
    final output = data['output'];
    if (output is! Map) return '';
    final choices = output['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map) {
        final msg = first['message'];
        if (msg is Map) {
          final content = msg['content'];
          if (content is String) return content;
          if (content is List) {
            return content
                .whereType<Map>()
                .map((part) => part['text'])
                .whereType<String>()
                .join();
          }
        }
      }
    }
    return '';
  }
}

/// Minimal 16-bit mono 16 kHz PCM WAV of [seconds] silence, used to exercise
/// a configured endpoint from the settings page ("test connection").
Uint8List silentWav({int seconds = 1}) {
  const sampleRate = 16000;
  final dataLen = sampleRate * 2 * seconds;
  final bytes = ByteData(44 + dataLen);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      bytes.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  bytes.setUint32(4, 36 + dataLen, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little); // PCM chunk size
  bytes.setUint16(20, 1, Endian.little); // PCM format
  bytes.setUint16(22, 1, Endian.little); // mono
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  bytes.setUint16(32, 2, Endian.little); // block align
  bytes.setUint16(34, 16, Endian.little); // bits per sample
  ascii(36, 'data');
  bytes.setUint32(40, dataLen, Endian.little);
  return bytes.buffer.asUint8List();
}
