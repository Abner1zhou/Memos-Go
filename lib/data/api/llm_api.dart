import 'package:dio/dio.dart';

/// Coarse error class so UI can localize without parsing messages.
enum LlmErrorKind { timeout, unreachable, auth, http, unknown }

/// Typed error surfaced by the LLM layer so UI can show friendly messages.
class LlmApiException implements Exception {
  const LlmApiException(this.message,
      {this.statusCode, this.cause, this.kind = LlmErrorKind.unknown});

  final String message;
  final int? statusCode;
  final Object? cause;
  final LlmErrorKind kind;

  @override
  String toString() => 'LlmApiException($statusCode): $message';
}

/// Coarse class of a transport failure: timeouts, unreachable hosts and
/// auth rejections get dedicated localized copy in the UI.
LlmErrorKind _kindOf(DioException e) {
  final status = e.response?.statusCode;
  if (status == 401 || status == 403) return LlmErrorKind.auth;
  if (status != null) return LlmErrorKind.http;
  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
      LlmErrorKind.timeout,
    DioExceptionType.connectionError => LlmErrorKind.unreachable,
    _ => LlmErrorKind.unknown,
  };
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
            kind: _kindOf(e),
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
          'max_tokens': ?maxTokens,
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
      throw LlmApiException(_llmMessageOf(e), cause: e, kind: _kindOf(e));
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
      // OpenAI 兼容服务按 index 对齐向量与输入；缺 index 时退回出现顺序
      // （ordinal），坏项（非 Map / 非 List embedding）直接跳过。
      final entries = <(int, List<double>)>[];
      var ordinal = 0;
      for (final item in list) {
        final order = ordinal++;
        if (item is! Map) continue;
        final raw = item['embedding'];
        if (raw is! List) continue;
        final index = item['index'];
        entries.add((
          index is int ? index : order,
          raw.whereType<num>().map((n) => n.toDouble()).toList(),
        ));
      }
      entries.sort((a, b) => a.$1.compareTo(b.$1));
      return [for (final e in entries) e.$2];
    } on LlmApiException {
      rethrow;
    } on DioException catch (e) {
      final inner = e.error;
      if (inner is LlmApiException) throw inner;
      throw LlmApiException(_llmMessageOf(e), cause: e, kind: _kindOf(e));
    }
  }
}
