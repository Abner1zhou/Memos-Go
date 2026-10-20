import 'dart:convert' as convert;

import 'package:characters/characters.dart';
import 'package:drift/drift.dart';

import '../../core/utils/text_clip.dart';
import 'app_database.dart';

part 'chat_dao.g.dart';

/// One citation of an assistant answer: `[n]` marker + source memo.
class ChatSource {
  const ChatSource({required this.n, required this.uid, required this.excerpt});

  final int n;
  final String uid;
  final String excerpt;

  Map<String, dynamic> toJson() => {'n': n, 'uid': uid, 'excerpt': excerpt};
}

/// Defensive JSON codec for the sources column (AGENTS.md: parse must not
/// crash on missing/mistyped fields).
String sourcesToJson(List<ChatSource> sources) =>
    convert.jsonEncode([for (final s in sources) s.toJson()]);

List<ChatSource> sourcesFromJson(String raw) {
  try {
    final json = convert.jsonDecode(raw);
    if (json is! List) return const [];
    return [
      for (final item in json)
        if (item is Map && item['n'] is int && item['uid'] is String)
          ChatSource(
              n: item['n'] as int,
              uid: item['uid'] as String,
              excerpt: item['excerpt'] is String ? item['excerpt'] as String : ''),
    ];
  } catch (_) {
    return const [];
  }
}

extension ChatMessagesRowSources on ChatMessagesRow {
  List<ChatSource> get parsedSources => sourcesFromJson(sources);
}

/// All local-database access for memory chats. Scoped by [accountId] like
/// every other DAO; chats never sync to the server.
@DriftAccessor(tables: [ChatSessions, ChatMessages])
class ChatDao extends DatabaseAccessor<AppDatabase> with _$ChatDaoMixin {
  ChatDao(super.db);

  Stream<List<ChatSessionsRow>> watchSessions(String accountId) {
    final query = select(chatSessions)
      ..where((s) => s.accountId.equals(accountId))
      ..orderBy([(s) => OrderingTerm.desc(s.updatedAt)]);
    return query.watch();
  }

  Future<ChatSessionsRow> createSession(String accountId) async {
    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toRadixString(36);
    await into(chatSessions).insert(ChatSessionsCompanion.insert(
        accountId: accountId, id: id, createdAt: now, updatedAt: now));
    return ChatSessionsRow(
        accountId: accountId, id: id, title: '', createdAt: now, updatedAt: now);
  }

  Future<void> appendMessage(
    String accountId,
    String sessionId, {
    required String role,
    required String content,
    List<ChatSource> sources = const [],
    required DateTime now,
  }) =>
      transaction(() async {
        final maxSeq = await (selectOnly(chatMessages)
              ..addColumns([chatMessages.seq.max()])
              ..where(chatMessages.accountId.equals(accountId) &
                  chatMessages.sessionId.equals(sessionId)))
            .getSingle();
        final seq = (maxSeq.read(chatMessages.seq.max()) ?? 0) + 1;
        await into(chatMessages).insert(ChatMessagesCompanion.insert(
          accountId: accountId,
          sessionId: sessionId,
          seq: seq,
          role: role,
          content: content,
          sources: Value(sourcesToJson(sources)),
          createdAt: now,
        ));
        // First user turn names the session (flomo-style).
        final session = await (select(chatSessions)
              ..where((s) =>
                  s.accountId.equals(accountId) & s.id.equals(sessionId)))
            .getSingle();
        if (role == 'user' && session.title.isEmpty && content.trim().isNotEmpty) {
          final title = content.trim();
          // Grapheme-safe 30-char cap: a UTF-16-blind substring could split
          // a surrogate pair and store a broken emoji in the title.
          final clipped =
              title.characters.length > 30 ? clipText(title, 30) : title;
          await (update(chatSessions)
                ..where((s) =>
                    s.accountId.equals(accountId) & s.id.equals(sessionId)))
              .write(ChatSessionsCompanion(
                  title: Value(clipped),
                  updatedAt: Value(now)));
        } else {
          await (update(chatSessions)
                ..where((s) =>
                    s.accountId.equals(accountId) & s.id.equals(sessionId)))
              .write(ChatSessionsCompanion(updatedAt: Value(now)));
        }
      });

  Stream<List<ChatMessagesRow>> watchMessages(String accountId, String sessionId) {
    final query = select(chatMessages)
      ..where((m) =>
          m.accountId.equals(accountId) & m.sessionId.equals(sessionId))
      ..orderBy([(m) => OrderingTerm.asc(m.seq)]);
    return query.watch();
  }

  /// The chronologically ordered tail of a session's messages.
  Future<List<ChatMessagesRow>> lastMessages(
      String accountId, String sessionId, int limit) async {
    final query = select(chatMessages)
      ..where((m) =>
          m.accountId.equals(accountId) & m.sessionId.equals(sessionId))
      ..orderBy([(m) => OrderingTerm.desc(m.seq)])
      ..limit(limit);
    final rows = await query.get();
    return rows.reversed.toList();
  }

  Future<void> deleteSession(String accountId, String sessionId) =>
      transaction(() async {
        await (delete(chatMessages)
              ..where((m) =>
                  m.accountId.equals(accountId) &
                  m.sessionId.equals(sessionId)))
            .go();
        await (delete(chatSessions)
              ..where((s) =>
                  s.accountId.equals(accountId) & s.id.equals(sessionId)))
            .go();
      });
}
