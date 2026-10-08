import 'dart:convert' as convert;

import 'package:dio/dio.dart';

import '../models/models.dart';
import 'memos_api_client.dart';

/// All Memos v1 REST calls used by the app.
class MemosApi {
  MemosApi(this.dio, {required this.baseUrl});

  final Dio dio;
  final String baseUrl;

  // ---------------------------------------------------------- auth / user

  /// `POST /auth/signin` with username + password.
  /// Returns the signed-in user and a short-lived access token.
  Future<(User, String)> signInWithPassword(String username, String password) async {
    final data = await _post(
      '/auth/signin',
      query: {},
      body: {
        'passwordCredentials': {'username': username, 'password': password},
      },
    );
    final user = User.fromJson((data['user'] as Map?)?.cast<String, dynamic>() ?? {});
    final token = data['accessToken'] as String? ?? '';
    return (user, token);
  }

  /// `GET /auth/me` (v0.31+). Falls back to `GET /users/me` on older servers.
  Future<User> getCurrentUser() async {
    try {
      final data = await _get('/auth/me');
      return User.fromJson((data['user'] as Map?)?.cast<String, dynamic>() ?? {});
    } on MemosApiException catch (e) {
      if (e.isNotFound || e.statusCode == 501) {
        final data = await _get('/users/me');
        return User.fromJson(data.cast<String, dynamic>());
      }
      rethrow;
    }
  }

  /// `POST /users/{user}/personalAccessTokens` (v0.31+).
  /// Returns the one-time token value.
  Future<String> createPersonalAccessToken(
      String userUid, String description) async {
    final data = await _post('/users/$userUid/personalAccessTokens', body: {
      'description': description,
      'expiresInDays': 0,
    });
    return data['token'] as String? ?? '';
  }

  /// `GET /users/{username}:getStats` -> tag counts.
  Future<UserStats> getUserStats(String username) async {
    final data = await _get('/users/$username:getStats');
    return UserStats.fromJson(data.cast<String, dynamic>());
  }

  // --------------------------------------------------------------- memos

  Future<MemoListPage> listMemos({
    int pageSize = 50,
    String pageToken = '',
    String? filter,
    String orderBy = 'pinned desc, create_time desc',
  }) async {
    final data = await _get('/memos', query: {
      'pageSize': pageSize,
      if (pageToken.isNotEmpty) 'pageToken': pageToken,
      if (filter != null && filter.isNotEmpty) 'filter': filter,
      'orderBy': orderBy,
    });
    return MemoListPage(
      memos: (data['memos'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Memo.fromJson)
          .toList(),
      nextPageToken: data['nextPageToken'] as String? ?? '',
    );
  }

  Future<Memo> getMemo(String uid) async {
    final data = await _get('/memos/$uid');
    return Memo.fromJson(data.cast<String, dynamic>());
  }

  Future<Memo> createMemo({
    required String content,
    required MemoVisibility visibility,
  }) async {
    final data = await _post('/memos', body: {
      'content': content,
      'visibility': visibility.wireName,
    });
    return Memo.fromJson(data.cast<String, dynamic>());
  }

  /// [fields] uses proto field names, e.g. `content`, `visibility`, `pinned`.
  Future<Memo> updateMemo(Memo memo, List<String> fields) async {
    final data = await _patch(
      '/memos/${memo.uid}',
      query: {'updateMask': fields.join(',')},
      body: memo.toUpdateJson(),
    );
    return Memo.fromJson(data.cast<String, dynamic>());
  }

  Future<void> deleteMemo(String uid) async {
    await _delete('/memos/$uid');
  }

  /// Replaces the full attachment set of a memo.
  Future<void> setMemoAttachments(String memoUid, List<Attachment> attachments) async {
    await _patch('/memos/$memoUid/attachments', body: {
      'attachments': attachments.map((a) => a.toJson()).toList(),
    });
  }

  // --------------------------------------------------------- attachments

  /// `POST /attachments` with inline base64 content.
  Future<Attachment> createAttachment({
    required String filename,
    required String mimeType,
    required List<int> bytes,
  }) async {
    final data = await _post('/attachments', body: {
      'filename': filename,
      'type': mimeType,
      'content': base64Bytes(bytes),
    });
    return Attachment.fromJson(data.cast<String, dynamic>());
  }

  // ------------------------------------------------------------- helpers

  /// Runs [run] and rethrows the interceptor's [MemosApiException] directly
  /// so call sites can `on MemosApiException` without unwrapping Dio errors.
  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on MemosApiException {
      rethrow;
    } on DioException catch (e) {
      final inner = e.error;
      if (inner is MemosApiException) throw inner;
      throw MemosApiException(_fallbackMessage(e), cause: e);
    }
  }

  static String _fallbackMessage(DioException e) => switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'Connection timed out',
        DioExceptionType.connectionError => 'Cannot reach server',
        _ => e.message ?? 'Request failed',
      };

  Future<Map<String, dynamic>> _get(String path,
      {Map<String, dynamic>? query}) {
    return _guard(() async {
      final res = await dio.get<Map<dynamic, dynamic>>(path,
          queryParameters: query);
      return (res.data ?? const {}).cast<String, dynamic>();
    });
  }

  Future<Map<String, dynamic>> _post(String path,
      {required Map<String, dynamic> body, Map<String, dynamic>? query}) {
    return _guard(() async {
      final res = await dio.post<Map<dynamic, dynamic>>(path,
          data: body, queryParameters: query);
      return (res.data ?? const {}).cast<String, dynamic>();
    });
  }

  Future<Map<String, dynamic>> _patch(String path,
      {required Map<String, dynamic> body, Map<String, dynamic>? query}) {
    return _guard(() async {
      final res = await dio.patch<Map<dynamic, dynamic>>(path,
          data: body, queryParameters: query);
      return (res.data ?? const {}).cast<String, dynamic>();
    });
  }

  Future<void> _delete(String path) {
    return _guard(() async {
      await dio.delete<void>(path);
    });
  }
}

/// Base64 without line breaks, as protojson expects for `bytes` fields.
String base64Bytes(List<int> bytes) => convert.base64Encode(bytes);
