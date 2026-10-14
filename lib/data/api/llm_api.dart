import 'package:dio/dio.dart';

/// Typed error surfaced by the LLM layer so UI can show friendly messages.
class LlmApiException implements Exception {
  const LlmApiException(this.message, {this.statusCode, this.cause});

  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => 'LlmApiException($statusCode): $message';
}

/// Normalizes a user-entered OpenAI-compatible endpoint: adds https:// when
/// the scheme is missing and strips trailing slashes.
String normalizeLlmBaseUrl(String raw) {
  var url = raw.trim();
  if (url.isEmpty) return url;
  if (!url.startsWith(RegExp(r'https?://'))) url = 'https://$url';
  return url.replaceAll(RegExp(r'/+$'), '');
}

/// Returns whether [raw] fails to parse as an endpoint URL (scheme + host,
/// no spaces) for the caller to map to a localized message.
bool llmBaseUrlInvalid(String raw) {
  final url = normalizeLlmBaseUrl(raw);
  if (url.isEmpty || RegExp(r'\s').hasMatch(url)) return true;
  final uri = Uri.tryParse(url);
  return uri == null || !uri.hasScheme || uri.host.isEmpty;
}

/// Creates a [Dio] client pointed at an OpenAI-compatible endpoint base
/// (e.g. `https://api.deepseek.com/v1`). [apiKey] is sent as
/// `Authorization: Bearer` on every request.
Dio createLlmDio({required String baseUrl, required String apiKey}) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    // Long generations can take a while on slower services.
    receiveTimeout: const Duration(minutes: 3),
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
          error: LlmApiException(
            _llmMessageOf(e),
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
String _llmMessageOf(DioException e) {
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

/// Extracts an [LlmApiException] from a thrown object, if any.
LlmApiException? asLlmApiError(Object error) {
  if (error is LlmApiException) return error;
  if (error is DioException) {
    final inner = error.error;
    if (inner is LlmApiException) return inner;
  }
  return null;
}

/// One chat turn; [role] is `system` / `user` / `assistant`.
class LlmChatMessage {
  const LlmChatMessage({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// Client for an OpenAI-compatible chat-completions + embeddings endpoint.
/// P1 uses [chat] for the review digest; [embeddings] powers the settings
/// page connection test now and semantic search in P2.
class LlmApi {
  LlmApi(this.dio);

  final Dio dio;

  /// Sends a chat completion and returns the assistant text (empty string
  /// when the service returns no content).
  Future<String> chat({
    required String model,
    required List<LlmChatMessage> messages,
    int? maxTokens,
  }) async {
    try {
      final res = await dio.post<Map<dynamic, dynamic>>(
        '/chat/completions',
        data: {
          'model': model,
          'messages': messages.map((m) => m.toJson()).toList(),
          if (maxTokens != null) 'max_tokens': maxTokens,
        },
      );
      final data = (res.data ?? const {}).cast<String, dynamic>();
      final choices = data['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map) {
          final msg = first['message'];
          if (msg is Map) return msg['content'] as String? ?? '';
        }
      }
      return '';
    } on LlmApiException {
      rethrow;
    } on DioException catch (e) {
      final inner = e.error;
      if (inner is LlmApiException) throw inner;
      throw LlmApiException(_llmMessageOf(e), cause: e);
    }
  }

  /// Embeds [inputs] and returns one vector per input string.
  Future<List<List<double>>> embeddings({
    required String model,
    required List<String> inputs,
  }) async {
    try {
      final res = await dio.post<Map<dynamic, dynamic>>(
        '/embeddings',
        data: {
          'model': model,
          'input': inputs,
        },
      );
      final data = (res.data ?? const {}).cast<String, dynamic>();
      final list = data['data'];
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map((item) => (item['embedding'] as List? ?? const [])
              .whereType<num>()
              .map((n) => n.toDouble())
              .toList())
          .toList();
    } on LlmApiException {
      rethrow;
    } on DioException catch (e) {
      final inner = e.error;
      if (inner is LlmApiException) throw inner;
      throw LlmApiException(_llmMessageOf(e), cause: e);
    }
  }
}
