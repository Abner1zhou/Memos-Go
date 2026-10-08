import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/api/memos_api_client.dart';
import '../../providers/auth_providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _tokenController = TextEditingController();

  var _serverChecked = false;
  var _busy = false;
  String? _error;
  int _methodTab = 0; // 0 password, 1 token

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _checkServer() async {
    setState(() => _error = null);
    if (_serverController.text.trim().isEmpty) {
      setState(() => _error = null);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).probe(_serverController.text);
      setState(() => _serverChecked = true);
    } on MemosApiException {
      setState(() => _error = null);
      setState(() => _serverChecked = true);
      // The probe endpoint may not exist on every version; a well-formed
      // Memos server still deserves a login attempt.
    } catch (_) {
      setState(() => _error =
          AppLocalizations.of(context)!.serverUnreachable);
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _error = null);

    final baseUrl = _serverController.text.trim();
    if (baseUrl.isEmpty) {
      setState(() => _error = l10n.serverAddressEmpty);
      return;
    }
    if (_methodTab == 0) {
      if (_usernameController.text.trim().isEmpty ||
          _passwordController.text.isEmpty) {
        setState(() => _error = l10n.loginFailed);
        return;
      }
    } else if (_tokenController.text.trim().isEmpty) {
      setState(() => _error = l10n.loginFailed);
      return;
    }

    setState(() => _busy = true);
    try {
      if (_methodTab == 0) {
        await ref.read(authProvider.notifier).signInWithPassword(
              baseUrl: baseUrl,
              username: _usernameController.text.trim(),
              password: _passwordController.text,
            );
      } else {
        await ref.read(authProvider.notifier).signInWithToken(
              baseUrl: baseUrl,
              token: _tokenController.text.trim(),
            );
      }
      if (mounted) context.go('/memos');
    } on MemosApiException catch (e) {
      setState(() => _error = '${l10n.loginFailed}: ${e.message}');
    } catch (_) {
      setState(() => _error = l10n.serverUnreachable);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.seedColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.edit_note_rounded,
                          size: 42, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.loginTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.loginSubtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _serverController,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.url],
                      decoration: InputDecoration(
                        labelText: l10n.serverAddress,
                        hintText: l10n.serverAddressHint,
                        prefixIcon: const Icon(Icons.dns_outlined),
                        suffixIcon: _serverChecked
                            ? const Icon(Icons.check_circle,
                                color: Colors.green)
                            : null,
                      ),
                      onChanged: (_) {
                        if (_serverChecked) {
                          setState(() => _serverChecked = false);
                        }
                      },
                      onFieldSubmitted: (_) => _checkServer(),
                    ),
                    if (!_serverChecked) ...[
                      const SizedBox(height: 14),
                      FilledButton.tonal(
                        onPressed: _busy ? null : _checkServer,
                        child: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : Text(l10n.next),
                      ),
                    ] else ...[
                      const SizedBox(height: 18),
                      SegmentedButton<int>(
                        segments: [
                          ButtonSegment(
                              value: 0,
                              icon: const Icon(Icons.password_outlined),
                              label: Text(l10n.passwordLogin)),
                          ButtonSegment(
                              value: 1,
                              icon: const Icon(Icons.key_outlined),
                              label: Text(l10n.tokenLogin)),
                        ],
                        selected: {_methodTab},
                        onSelectionChanged: (s) =>
                            setState(() => _methodTab = s.first),
                      ),
                      const SizedBox(height: 18),
                      if (_methodTab == 0) ...[
                        TextFormField(
                          controller: _usernameController,
                          autofillHints: const [AutofillHints.username],
                          decoration: InputDecoration(
                            labelText: l10n.username,
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: l10n.password,
                            prefixIcon: const Icon(Icons.lock_outline),
                          ),
                          onFieldSubmitted: (_) => _submit(),
                        ),
                      ] else ...[
                        TextFormField(
                          controller: _tokenController,
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: l10n.accessToken,
                            hintText: l10n.accessTokenHint,
                            prefixIcon: const Icon(Icons.vpn_key_outlined),
                          ),
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.createTokenGuide,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text(l10n.login,
                                  style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style:
                            TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
