// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'embedding_dao.dart';

// ignore_for_file: type=lint
mixin _$EmbeddingDaoMixin on DatabaseAccessor<AppDatabase> {
  $MemoEmbeddingsTable get memoEmbeddings => attachedDatabase.memoEmbeddings;
  $MemosTable get memos => attachedDatabase.memos;
  EmbeddingDaoManager get managers => EmbeddingDaoManager(this);
}

class EmbeddingDaoManager {
  final _$EmbeddingDaoMixin _db;
  EmbeddingDaoManager(this._db);
  $$MemoEmbeddingsTableTableManager get memoEmbeddings =>
      $$MemoEmbeddingsTableTableManager(
        _db.attachedDatabase,
        _db.memoEmbeddings,
      );
  $$MemosTableTableManager get memos =>
      $$MemosTableTableManager(_db.attachedDatabase, _db.memos);
}
