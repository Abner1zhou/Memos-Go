import 'package:dio/dio.dart';

/// Typed error surfaced by the API layer so UI can show friendly messages.
class MemosApiException implements Exception {
  const MemosApiException(this.message, {this.statusCode, this.cause});

  final String message;
  final int? statusCode;
  final Object? cause;

  bool get isNotFound => statusCode == 404;

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  @override
  String toString() => 'MemosApiException($statusCode): $message';
}

/// Creates a [Dio] client pointed at a Memos server.
///
/// [baseUrl] must be normalized (scheme + host + port, no trailing slash,
/// no /api suffix). [token] is sent as `Authorization: Bearer` on every
/// request when non-empty.
Dio createMemosDio({required String baseUrl, String? token}) {
  final dio = Dio(BaseOptions(
    baseUrl: '$baseUrl/api/v1',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 60),
    headers: {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    },
  ));
  dio.interceptors.add(InterceptorsWrapper(
    onError: (e, handler) {
      handler.reject(
        DioException(
          requestOptions: e.requestOptions,
          error: MemosApiException(
            _messageOf(e),
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

String _messageOf(DioException e) {
  final data = e.response?.data;
  if (data is Map<String, dynamic>) {
    final msg = data['message'] as String?;
    if (msg != null && msg.isNotEmpty) return msg;
  }
  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
      'Connection timed out',
    DioExceptionType.connectionError => 'Cannot reach server',
    _ => e.response?.statusMessage ?? 'Request failed',
  };
}

/// Extracts a `MemosApiException` from a thrown object, if any.
MemosApiException? asMemosApiError(Object error) {
  if (error is MemosApiException) return error;
  if (error is DioException) {
    final inner = error.error;
    if (inner is MemosApiException) return inner;
  }
  return null;
}

/// Normalizes a user-entered server address:
/// adds https:// when the scheme is missing and strips trailing slashes
/// and accidental `/api` or `/api/v1` suffixes.
String normalizeBaseUrl(String raw) {
  var url = raw.trim();
  if (url.isEmpty) return url;
  if (!url.startsWith(RegExp(r'https?://'))) url = 'https://$url';
  url = url.replaceAll(RegExp(r'/+$'), '');
  url = url.replaceFirst(RegExp(r'/api/v1$'), '');
  url = url.replaceFirst(RegExp(r'/api$'), '');
  return url;
}

/// Absolute URL for attachment binary content served by the file server.
String attachmentFileUrl(String baseUrl, String attachmentUid,
        {bool thumbnail = false}) =>
    '$baseUrl/file/attachments/$attachmentUid'
    '${thumbnail ? '?thumbnail=true' : ''}';
