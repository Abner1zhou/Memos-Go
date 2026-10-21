import 'dart:async';

import '../../core/utils/text_clip.dart';
import '../api/llm_api.dart';
import '../local/app_database.dart';
import '../local/chat_dao.dart';
import '../repositories/llm_repository.dart';
import 'retrieval.dart';

/// One in-flight turn: citations known up front + the answer stream. The
/// deltas stream persists the completed answer (with sources) to the
/// session when it closes.
class RagChatTurn {
  const RagChatTurn({required this.sources, required this.deltas});

  final List<ChatSource> sources;
  final Stream<String> deltas;
}

/// RAG orchestration per spec §6: every turn re-retrieves, assembles a
/// numbered-excerpt context and streams the answer. Guards: fixed top-12
/// retrieval, 400-char excerpts, only the last [historyMessages] messages
/// of history ride along.
class RagChatEngine {
  RagChatEngine({
    required this.accountId,
    required this._db,
    required this._repository,
    required this._retrieval,
  });

  static const excerptChars = 400;
  static const historyMessages = 8;

  /// Per-message cap on the history that rides back into the prompt
  /// (spec §6 上下文 token 上限): the [historyMessages] window bounds how
  /// many messages return, this bounds how big any one of them can be, so
  /// one giant answer can't re-enter the context verbatim.
  static const historyClipChars = 1000;

  final String accountId;
  final AppDatabase _db;
  final LlmRepository _repository;
  final RetrievalService _retrieval;

  Future<RagChatTurn> send({
    required String sessionId,
    required String question,
    required String language,
  }) async {
    final settings = await _repository.load();
    if (!settings.isConfigured) {
      throw const LlmApiException('Chat model not configured');
    }

    // History window BEFORE this turn's user message lands.
    final history = await _db.chatDao
        .lastMessages(accountId, sessionId, historyMessages);

    // Retrieval failures are non-fatal: chat degrades to no citations.
    List<ScoredMemo> hits = const [];
    try {
      hits = await _retrieval.retrieve(accountId, question);
    } catch (_) {
      // surfaced by the empty sources
    }
    final sources = [
      for (var i = 0; i < hits.length; i++)
        ChatSource(
            // uid carries the full memo name ('memos/<id>') — Task 6's
            // citation tap strips the prefix for navigation.
            n: i + 1,
            uid: hits[i].record.memo.name,
            excerpt: clipText(hits[i].record.memo.content, excerptChars)),
    ];

    final messages = <LlmChatMessage>[
      LlmChatMessage(role: 'system', content: _systemPrompt(language)),
      ...history.map((m) => LlmChatMessage(
          role: m.role,
          // Same clip style as excerpts: the window bounds count, this
          // bounds per-message size (see [historyClipChars]).
          content: clipText(m.content, historyClipChars))),
      LlmChatMessage(
          role: 'user', content: _userPrompt(question, hits, language)),
    ];

    final now = DateTime.now();
    await _db.chatDao.appendMessage(accountId, sessionId,
        role: 'user', content: question, now: now);

    // Generation starts eagerly — the UI listens to [deltas] right after
    // `send` returns, and a buffered controller replays every chunk to
    // that late listener. On success — or after a mid-stream failure,
    // keeping whatever streamed — the answer + sources are persisted as
    // the assistant turn before the deltas stream closes.
    final controller = StreamController<String>();
    Future<void> pump() async {
      final buffer = StringBuffer();
      Object? error;
      try {
        await for (final chunk
            in _repository.chatStream(settings, messages: messages)) {
          buffer.write(chunk);
          controller.add(chunk);
        }
      } catch (e) {
        error = e;
      }
      // Persist the assistant turn: the full answer on success, whatever
      // streamed before a failure (an empty failed stream leaves no
      // message). The error itself is surfaced through `deltas`.
      if (buffer.isNotEmpty || error == null) {
        try {
          await _db.chatDao.appendMessage(accountId, sessionId,
              role: 'assistant',
              content: buffer.toString(),
              sources: sources,
              now: DateTime.now());
        } catch (e) {
          error ??= e;
        }
      }
      if (error != null) controller.addError(error);
      await controller.close();
    }

    unawaited(pump());
    // Yield one event-loop turn so the pump's upstream (chatStream) is
    // actually running before send resolves — callers and tests may inspect
    // the request's side effects right after awaiting send.
    await Future<void>.delayed(Duration.zero);
    return RagChatTurn(sources: sources, deltas: controller.stream);
  }

  static String _systemPrompt(String language) => language == 'en'
      ? 'You are a warm journaling assistant answering ONLY from the '
          'numbered memories quoted in the user message. Do not invent '
          'facts; if the memories cannot answer, say so plainly. Cite the '
          'memories you used as [1], [2] right after the claim. Reply in '
          'English Markdown.'
      : '你是一位温暖的日记助手，仅基于用户消息中引用的编号记忆回答，不要编造事实；'
          '记忆无法回答时明确说明。引用某条记忆时在相应结论后标注 [1]、[2] 编号。'
          '用中文以 Markdown 回复。';

  static String _userPrompt(
      String question, List<ScoredMemo> hits, String language) {
    // The question rides into every prompt; give it the same per-message
    // budget as history so a giant paste can't blow the context either.
    final q = clipText(question, historyClipChars);
    final b = StringBuffer();
    if (hits.isEmpty) {
      b.writeln(language == 'en'
          ? '(No related memories found.)'
          : '（未找到相关记忆。）');
    } else {
      b.writeln(language == 'en' ? 'Related memories:' : '相关记忆：');
      for (var i = 0; i < hits.length; i++) {
        final memo = hits[i].record.memo;
        final created = memo.createTime?.toLocal();
        final date = created == null
            ? ''
            : '${created.year}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')}';
        final tags = memo.tags.isEmpty ? '' : ' #${memo.tags.join(' #')}';
        b.writeln('[${i + 1}] $date$tags');
        b.writeln(clipText(memo.content, excerptChars));
      }
    }
    b.writeln();
    b.writeln(language == 'en' ? 'Question: $q' : '问题：$q');
    return b.toString();
  }
}
