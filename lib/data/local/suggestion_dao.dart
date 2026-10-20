import 'dart:convert' as convert;

import 'package:drift/drift.dart';

import 'app_database.dart';

part 'suggestion_dao.g.dart';

/// Parsed suggestion payload (tags + related memo names).
class MemoSuggestion {
  const MemoSuggestion({required this.tags, required this.relatedUids});

  final List<String> tags;
  final List<String> relatedUids;
}

/// Defensive JSON codec: any malformed payload (bad JSON, mistyped fields)
/// yields null instead of crashing (AGENTS.md rule).
String suggestionToJson(MemoSuggestion s) => convert.jsonEncode({
      'tags': s.tags,
      'related': s.relatedUids,
    });

MemoSuggestion? suggestionFromJson(String raw) {
  try {
    final json = convert.jsonDecode(raw);
    if (json is! Map) return null;
    final tags = json['tags'];
    final related = json['related'];
    if (tags is! List || related is! List) return null;
    return MemoSuggestion(
      tags: [for (final t in tags) if (t is String) t],
      relatedUids: [for (final r in related) if (r is String) r],
    );
  } catch (_) {
    return null;
  }
}

extension MemoSuggestionsRowParsed on MemoSuggestionsRow {
  List<String> get tagList => _stringList(tagsJson);
  List<String> get relatedUidList => _stringList(relatedUidsJson);
}

List<String> _stringList(String raw) {
  try {
    final json = convert.jsonDecode(raw);
    if (json is! List) return const [];
    return [for (final e in json) if (e is String) e];
  } catch (_) {
    return const [];
  }
}

/// All local-database access for save-time suggestions. Scoped by
/// [accountId]; rows cascade with memo deletion/sweep/purge.
@DriftAccessor(tables: [MemoSuggestions, MemoTags, Memos])
class SuggestionDao extends DatabaseAccessor<AppDatabase>
    with _$SuggestionDaoMixin {
  SuggestionDao(super.db);

  Stream<MemoSuggestionsRow?> watchSuggestion(String accountId, String memoUid) {
    final query = select(memoSuggestions)
      ..where((s) =>
          s.accountId.equals(accountId) & s.memoUid.equals(memoUid));
    return query.watchSingleOrNull();
  }

  Future<void> upsert(
    String accountId,
    String memoUid, {
    required int contentHash,
    required MemoSuggestion suggestion,
    required DateTime now,
  }) =>
      into(memoSuggestions).insertOnConflictUpdate(
        MemoSuggestionsCompanion.insert(
          accountId: accountId,
          memoUid: memoUid,
          contentHash: contentHash,
          tagsJson: Value(suggestion.tags.isEmpty
              ? '[]'
              : convert.jsonEncode(suggestion.tags)),
          relatedUidsJson: Value(suggestion.relatedUids.isEmpty
              ? '[]'
              : convert.jsonEncode(suggestion.relatedUids)),
          createdAt: now,
        ),
      );

  /// The account's known tags (deduped, sorted) fed to the suggestion prompt.
  Future<List<String>> distinctTags(String accountId) async {
    final query = selectOnly(memoTags)
      ..addColumns([memoTags.tag])
      ..where(memoTags.accountId.equals(accountId))
      ..groupBy([memoTags.tag])
      ..orderBy([OrderingTerm.asc(memoTags.tag)]);
    final rows = await query.get();
    return [for (final row in rows) row.read(memoTags.tag)!];
  }

  Future<void> deleteForMemo(String accountId, String memoUid) =>
      (delete(memoSuggestions)
            ..where((s) =>
                s.accountId.equals(accountId) & s.memoUid.equals(memoUid)))
          .go();
}
