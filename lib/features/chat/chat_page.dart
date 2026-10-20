import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/llm_errors.dart';
import '../../core/widgets/memo_markdown.dart';
import '../../data/local/app_database.dart';
import '../../data/local/chat_dao.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers/auth_providers.dart';
import '../../providers/llm_providers.dart';
import '../../providers/rag_chat_providers.dart';
import '../../providers/sync_providers.dart' show appDatabaseProvider;

/// `/chat`: RAG conversation over the local memory mirror. One page, a
/// sessions bottom sheet, streaming answers with tappable `[n]` citations.
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  String? _sessionId;
  List<ChatMessagesRow> _messages = const [];
  StreamSubscription<List<ChatMessagesRow>>? _messagesSub;

  bool _busy = false;
  String? _error;
  StringBuffer? _pending;
  StreamSubscription<String>? _deltaSub;

  ChatDao get _chatDao => ref.read(appDatabaseProvider).chatDao;
  String get _accountId =>
      ref.read(authProvider).activeAccount?.id ?? '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final sessions = await _chatDao.watchSessions(_accountId).first;
      if (!mounted || sessions.isEmpty) return;
      setState(() => _sessionId = sessions.first.id);
    });
  }

  @override
  void dispose() {
    _deltaSub?.cancel();
    _messagesSub?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _subscribeMessages(String sessionId) {
    _messagesSub?.cancel();
    _messagesSub = _chatDao.watchMessages(_accountId, sessionId).listen(
        (messages) {
      if (mounted) setState(() => _messages = messages);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final configured = ref.watch(llmProvider.select((s) => s.isConfigured));
    // Re-subscribe when the active session changes (incl. first creation).
    final sessionId = _sessionId;
    if (sessionId != null && _messagesSub == null) {
      // The microtask may run after dispose, or after a newer subscription
      // (session switch / new session) took over: bail instead of
      // resubscribing a dead page to a stale session.
      Future.microtask(() {
        if (!mounted || _messagesSub != null) return;
        _subscribeMessages(sessionId);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chatTitle),
        actions: [
          IconButton(
            tooltip: l10n.chatHistory,
            icon: const Icon(Icons.history_rounded),
            onPressed: _showSessions,
          ),
        ],
      ),
      body: !configured
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.forum_outlined,
                      size: 52, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(l10n.chatUnconfigured,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () => context.push('/settings/llm'),
                    child: Text(l10n.chatGoConfig),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(_error!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.error)),
                  ),
                Expanded(
                  child: _messages.isEmpty && _pending == null
                      ? Center(
                          child: Text(l10n.chatEmpty,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.all(12),
                          itemCount: _messages.length + (_pending != null ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index < _messages.length) {
                              return _bubble(context, _messages[index], null);
                            }
                            return _pendingBubble(context);
                          },
                        ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(
                                hintText: l10n.chatInputHint,
                                isDense: true,
                                border: const OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          icon: const Icon(Icons.send_rounded),
                          onPressed: _busy ? null : _send,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _bubble(BuildContext context, ChatMessagesRow row, List<ChatSource>? overrideSources) {
    final theme = Theme.of(context);
    final isUser = row.role == 'user';
    final sources = overrideSources ?? row.parsedSources;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isUser)
              Text(row.content, style: theme.textTheme.bodyMedium)
            else ...[
              MemoMarkdown(
                content: row.content,
                onCiteTap: sources.isEmpty
                    ? null
                    : (n) => _openSource(sources, n),
              ),
              if (sources.isNotEmpty) ...[
                const SizedBox(height: 8),
                _sourcesRow(context, sources),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _pendingBubble(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_pending?.toString() ?? '',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 6),
            const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
      ),
    );
  }

  Widget _sourcesRow(BuildContext context, List<ChatSource> sources) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final source in sources)
          ActionChip(
            avatar: Text('[${source.n}]',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.primary)),
            label: Text(
              source.excerpt.isEmpty ? source.uid : source.excerpt,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
            onPressed: () => context.push('/memos/detail/${source.uid.split('/').last}'),
          ),
      ],
    );
  }

  void _openSource(List<ChatSource> sources, int n) {
    final hit = sources.where((s) => s.n == n).firstOrNull;
    if (hit != null) {
      context.push('/memos/detail/${hit.uid.split('/').last}');
    }
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context)!;
    // Read before the awaits below (use_build_context_synchronously).
    final language = Localizations.localeOf(context).languageCode;
    final question = _input.text.trim();
    if (question.isEmpty || _busy) return;
    final engine = ref.read(ragChatEngineProvider);
    if (engine == null) return;

    // Claim the turn SYNCHRONOUSLY, before any await: two rapid sends both
    // reach `_send()` with a stale button otherwise, and both would pass
    // the `_busy` check above — double sessions, double user rows. Stays
    // true through the turn until the deltas onDone/onError reset it; the
    // catch below resets it on the pre-stream failure paths.
    setState(() {
      _error = null;
      _busy = true;
    });
    var sessionId = _sessionId;
    try {
      if (sessionId == null) {
        final session = await _chatDao.createSession(_accountId);
        sessionId = session.id;
        setState(() => _sessionId = sessionId);
        _subscribeMessages(sessionId);
      }
      final turn = await engine.send(
          sessionId: sessionId, question: question, language: language);
      // Disposed mid-send: no listener can attach to [turn.deltas]; bail
      // instead of crashing (FlutterError escapes `on Exception catch`).
      if (!mounted) return;
      _input.clear();
      setState(() {
        _pending = StringBuffer();
      });
      _deltaSub?.cancel();
      _deltaSub = turn.deltas.listen(
        (chunk) {
          _pending?.write(chunk);
          if (mounted) setState(() {});
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            _busy = false;
            _pending = null;
          });
        },
        onError: (Object e) {
          if (!mounted) return;
          setState(() {
            _busy = false;
            _pending = null;
            _error = llmErrorMessage(l10n, e);
          });
        },
      );
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = llmErrorMessage(l10n, e);
      });
    }
  }

  Future<void> _showSessions() async {
    final l10n = AppLocalizations.of(context)!;
    final accountId = _accountId;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Text(l10n.chatHistory,
                  style: Theme.of(sheetContext).textTheme.titleSmall),
            ),
            Flexible(
              child: StreamBuilder<List<ChatSessionsRow>>(
                stream: _chatDao.watchSessions(accountId),
                builder: (context, snap) {
                  final sessions = snap.data ?? const <ChatSessionsRow>[];
                  if (sessions.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(l10n.chatEmpty,
                          style: Theme.of(sheetContext).textTheme.bodySmall),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                            session.title.isEmpty ? l10n.chatNewSession : session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                            '${session.updatedAt.toLocal()}'.substring(0, 16)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: sheetContext,
                              builder: (dialogContext) => AlertDialog(
                                content: Text(l10n.chatDeleteSessionConfirm),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: Text(l10n.cancel),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, true),
                                    child: Text(l10n.confirm),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true) return;
                            await _chatDao.deleteSession(accountId, session.id);
                            if (!mounted) return;
                            if (_sessionId == session.id) {
                              setState(() => _sessionId = null);
                              _messagesSub?.cancel();
                              _messagesSub = null;
                              setState(() => _messages = const []);
                            }
                          },
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          setState(() => _sessionId = session.id);
                          _messagesSub?.cancel();
                          _messagesSub = null;
                          _subscribeMessages(session.id);
                        },
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l10n.chatNewSession),
                onPressed: () {
                  Navigator.pop(sheetContext);
                  setState(() => _sessionId = null);
                  _messagesSub?.cancel();
                  _messagesSub = null;
                  setState(() => _messages = const []);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
