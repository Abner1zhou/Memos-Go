import 'dart:convert' as convert;

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/memos_api.dart';
import '../api/memos_api_client.dart';
import '../models/models.dart';

/// A saved server account.
class ServerAccount {
  ServerAccount({
    required this.id,
    required this.baseUrl,
    required this.token,
    required this.user,
  });

  final String id;
  final String baseUrl;
  final String token;
  final User user;

  Map<String, dynamic> toJson() => {
        'id': id,
        'baseUrl': baseUrl,
        'token': token,
        'user': user.toJson(),
      };

  factory ServerAccount.fromJson(Map<String, dynamic> json) => ServerAccount(
        id: json['id'] as String,
        baseUrl: json['baseUrl'] as String,
        token: json['token'] as String,
        user: User.fromJson((json['user'] as Map?)?.cast<String, dynamic>() ?? {}),
      );
}

/// Owns the persisted list of server accounts and the login flows.
///
/// Login strategy:
/// - password: `POST /auth/signin` -> create a never-expiring personal
///   access token with the returned short-lived JWT. On servers older than
///   v0.31 (no PAT endpoint) the sign-in JWT is stored instead.
/// - token: the user pastes a PAT created in the web UI; it is validated by
///   fetching the current user.
class AuthRepository {
  AuthRepository({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'memos_go.accounts';
  static const _activeKey = 'memos_go.activeAccountId';

  final FlutterSecureStorage _storage;
  List<ServerAccount>? _cached;

  Future<List<ServerAccount>> loadAccounts() async {
    if (_cached != null) return _cached!;
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) {
      _cached = [];
      return _cached!;
    }
    try {
      final list = (convert.jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => ServerAccount.fromJson(e.cast<String, dynamic>()))
          .toList();
      _cached = list;
    } catch (_) {
      _cached = [];
    }
    return _cached!;
  }

  Future<String?> activeAccountId() async {
    final accounts = await loadAccounts();
    if (accounts.length == 1) return accounts.first.id;
    return _storage.read(key: _activeKey);
  }

  Future<void> setActiveAccount(String id) async {
    await _storage.write(key: _activeKey, value: id);
  }

  Future<void> upsertAccount(ServerAccount account) async {
    final accounts = await loadAccounts();
    final idx = accounts.indexWhere((a) => a.id == account.id);
    if (idx >= 0) {
      accounts[idx] = account;
    } else {
      accounts.add(account);
    }
    await _persist(accounts);
  }

  Future<void> removeAccount(String id) async {
    final accounts = await loadAccounts();
    accounts.removeWhere((a) => a.id == id);
    await _persist(accounts);
    if (await _storage.read(key: _activeKey) == id) {
      await _storage.delete(key: _activeKey);
    }
  }

  Future<void> _persist(List<ServerAccount> accounts) async {
    _cached = accounts;
    await _storage.write(
      key: _storageKey,
      value: convert.jsonEncode(accounts.map((a) => a.toJson()).toList()),
    );
  }

  /// Quick reachability probe before attempting login.
  Future<InstanceStatus> probe(String rawBaseUrl) async {
    final baseUrl = normalizeBaseUrl(rawBaseUrl);
    final dio = createMemosDio(baseUrl: baseUrl);
    try {
      final res = await dio.get<Map<dynamic, dynamic>>('/auth/status');
      return InstanceStatus.fromJson(
          (res.data ?? const {}).cast<String, dynamic>());
    } on DioException catch (e) {
      // 401/403/404 still prove the host is a reachable Memos instance.
      final inner = e.error;
      if (inner is MemosApiException &&
          (inner.isUnauthorized || inner.isNotFound)) {
        return const InstanceStatus();
      }
      if (e.response != null) return const InstanceStatus();
      rethrow;
    }
  }

  /// Password login. Returns the account to persist.
  Future<ServerAccount> loginWithPassword({
    required String rawBaseUrl,
    required String username,
    required String password,
  }) async {
    final baseUrl = normalizeBaseUrl(rawBaseUrl);
    final api = MemosApi(createMemosDio(baseUrl: baseUrl), baseUrl: baseUrl);

    final (user, accessToken) = await api.signInWithPassword(username, password);
    if (user.name.isEmpty || accessToken.isEmpty) {
      throw const MemosApiException('Sign-in response missing user or token');
    }

    // Try to mint a never-expiring PAT with the short-lived JWT.
    String token = accessToken;
    try {
      final authedApi =
          MemosApi(createMemosDio(baseUrl: baseUrl, token: accessToken),
              baseUrl: baseUrl);
      token = await authedApi.createPersonalAccessToken(user.uid, 'MemosGo');
    } on MemosApiException catch (e) {
      if (!e.isNotFound && e.statusCode != 501) rethrow;
      // Older server without the PAT endpoint: keep the sign-in JWT.
    }

    return ServerAccount(
      id: '$baseUrl|${user.username}',
      baseUrl: baseUrl,
      token: token,
      user: user,
    );
  }

  /// Personal-access-token login. Returns the account to persist.
  Future<ServerAccount> loginWithToken({
    required String rawBaseUrl,
    required String token,
  }) async {
    final baseUrl = normalizeBaseUrl(rawBaseUrl);
    final dio = createMemosDio(baseUrl: baseUrl, token: token.trim());
    final api = MemosApi(dio, baseUrl: baseUrl);
    final user = await api.getCurrentUser();
    return ServerAccount(
      id: '$baseUrl|${user.username.isNotEmpty ? user.username : user.uid}',
      baseUrl: baseUrl,
      token: token.trim(),
      user: user,
    );
  }
}
