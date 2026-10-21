// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'suggestion_dao.dart';

// ignore_for_file: type=lint
mixin _$SuggestionDaoMixin on DatabaseAccessor<AppDatabase> {
  $MemoSuggestionsTable get memoSuggestions => attachedDatabase.memoSuggestions;
  $MemoTagsTable get memoTags => attachedDatabase.memoTags;
  $MemosTable get memos => attachedDatabase.memos;
  SuggestionDaoManager get managers => SuggestionDaoManager(this);
}

class SuggestionDaoManager {
  final _$SuggestionDaoMixin _db;
  SuggestionDaoManager(this._db);
  $$MemoSuggestionsTableTableManager get memoSuggestions =>
      $$MemoSuggestionsTableTableManager(
        _db.attachedDatabase,
        _db.memoSuggestions,
      );
  $$MemoTagsTableTableManager get memoTags =>
      $$MemoTagsTableTableManager(_db.attachedDatabase, _db.memoTags);
  $$MemosTableTableManager get memos =>
      $$MemosTableTableManager(_db.attachedDatabase, _db.memos);
}
