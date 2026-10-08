import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/memo_repository.dart';

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository());

enum AuthStatus { loading, signedOut, signedIn }

class AuthState {
  const AuthState({
    this.status = AuthStatus.loading,
    this.accounts = const [],
    this.activeAccount,
  });

  final AuthStatus status;
  final List<ServerAccount> accounts;
  final ServerAccount? activeAccount;
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _restore();
    return const AuthState();
  }

  Future<void> _restore() async {
    final repo = ref.read(authRepositoryProvider);
    final accounts = await repo.loadAccounts();
    if (accounts.isEmpty) {
      state = AuthState(accounts: accounts);
      return;
    }
    final activeId = await repo.activeAccountId();
    final active = accounts.firstWhere(
      (a) => a.id == activeId,
      orElse: () => accounts.first,
    );
    await repo.setActiveAccount(active.id);
    state = AuthState(
      status: AuthStatus.signedIn,
      accounts: accounts,
      activeAccount: active,
    );
  }

  Future<void> signInWithPassword({
    required String baseUrl,
    required String username,
    required String password,
  }) =>
      _adopt(() => ref
          .read(authRepositoryProvider)
          .loginWithPassword(
              rawBaseUrl: baseUrl, username: username, password: password));

  Future<void> signInWithToken({
    required String baseUrl,
    required String token,
  }) =>
      _adopt(() => ref
          .read(authRepositoryProvider)
          .loginWithToken(rawBaseUrl: baseUrl, token: token));

  Future<void> _adopt(Future<ServerAccount> Function() login) async {
    final account = await login();
    final repo = ref.read(authRepositoryProvider);
    await repo.upsertAccount(account);
    await repo.setActiveAccount(account.id);
    ref.invalidate(memoRepositoryProvider);
    final accounts = await repo.loadAccounts();
    state = AuthState(
      status: AuthStatus.signedIn,
      accounts: accounts,
      activeAccount: account,
    );
  }

  Future<void> switchAccount(String id) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.setActiveAccount(id);
    final accounts = await repo.loadAccounts();
    final active = accounts.firstWhere((a) => a.id == id);
    ref.invalidate(memoRepositoryProvider);
    state = AuthState(
      status: AuthStatus.signedIn,
      accounts: accounts,
      activeAccount: active,
    );
  }

  /// Removes the account; falls back to another one when it was active.
  Future<void> removeAccount(String id) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.removeAccount(id);
    final accounts = await repo.loadAccounts();
    final wasActive = state.activeAccount?.id == id;
    if (accounts.isEmpty) {
      state = AuthState(accounts: accounts);
      return;
    }
    if (wasActive) {
      await switchAccount(accounts.first.id);
    } else {
      state = state.copyWith(accounts: accounts);
    }
  }

  Future<void> signOut() async {
    final current = state.activeAccount;
    if (current != null) {
      await removeAccount(current.id);
    }
  }
}

extension on AuthState {
  AuthState copyWith({
    AuthStatus? status,
    List<ServerAccount>? accounts,
    ServerAccount? activeAccount,
  }) =>
      AuthState(
        status: status ?? this.status,
        accounts: accounts ?? this.accounts,
        activeAccount: activeAccount ?? this.activeAccount,
      );
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// Repository for the active account; null when signed out.
final memoRepositoryProvider = Provider<MemoRepository?>((ref) {
  final auth = ref.watch(authProvider);
  final account = auth.activeAccount;
  if (account == null) return null;
  return MemoRepository(account);
});
