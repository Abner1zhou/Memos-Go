// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MemosTable extends Memos with TableInfo<$MemosTable, MemosRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uidMeta = const VerificationMeta('uid');
  @override
  late final GeneratedColumn<String> uid = GeneratedColumn<String>(
    'uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('NORMAL'),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _visibilityMeta = const VerificationMeta(
    'visibility',
  );
  @override
  late final GeneratedColumn<String> visibility = GeneratedColumn<String>(
    'visibility',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('PRIVATE'),
  );
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _attachmentsMeta = const VerificationMeta(
    'attachments',
  );
  @override
  late final GeneratedColumn<String> attachments = GeneratedColumn<String>(
    'attachments',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _attachmentsDirtyMeta = const VerificationMeta(
    'attachmentsDirty',
  );
  @override
  late final GeneratedColumn<bool> attachmentsDirty = GeneratedColumn<bool>(
    'attachments_dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("attachments_dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createTimeMeta = const VerificationMeta(
    'createTime',
  );
  @override
  late final GeneratedColumn<DateTime> createTime = GeneratedColumn<DateTime>(
    'create_time',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updateTimeMeta = const VerificationMeta(
    'updateTime',
  );
  @override
  late final GeneratedColumn<DateTime> updateTime = GeneratedColumn<DateTime>(
    'update_time',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _editedAtMeta = const VerificationMeta(
    'editedAt',
  );
  @override
  late final GeneratedColumn<DateTime> editedAt = GeneratedColumn<DateTime>(
    'edited_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(SyncStates.synced),
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    accountId,
    uid,
    state,
    content,
    visibility,
    pinned,
    attachments,
    attachmentsDirty,
    createTime,
    updateTime,
    editedAt,
    syncState,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memos';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemosRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('uid')) {
      context.handle(
        _uidMeta,
        uid.isAcceptableOrUnknown(data['uid']!, _uidMeta),
      );
    } else if (isInserting) {
      context.missing(_uidMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('visibility')) {
      context.handle(
        _visibilityMeta,
        visibility.isAcceptableOrUnknown(data['visibility']!, _visibilityMeta),
      );
    }
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    if (data.containsKey('attachments')) {
      context.handle(
        _attachmentsMeta,
        attachments.isAcceptableOrUnknown(
          data['attachments']!,
          _attachmentsMeta,
        ),
      );
    }
    if (data.containsKey('attachments_dirty')) {
      context.handle(
        _attachmentsDirtyMeta,
        attachmentsDirty.isAcceptableOrUnknown(
          data['attachments_dirty']!,
          _attachmentsDirtyMeta,
        ),
      );
    }
    if (data.containsKey('create_time')) {
      context.handle(
        _createTimeMeta,
        createTime.isAcceptableOrUnknown(data['create_time']!, _createTimeMeta),
      );
    }
    if (data.containsKey('update_time')) {
      context.handle(
        _updateTimeMeta,
        updateTime.isAcceptableOrUnknown(data['update_time']!, _updateTimeMeta),
      );
    }
    if (data.containsKey('edited_at')) {
      context.handle(
        _editedAtMeta,
        editedAt.isAcceptableOrUnknown(data['edited_at']!, _editedAtMeta),
      );
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, uid};
  @override
  MemosRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemosRow(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      uid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uid'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      visibility: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}visibility'],
      )!,
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned'],
      )!,
      attachments: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachments'],
      )!,
      attachmentsDirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}attachments_dirty'],
      )!,
      createTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}create_time'],
      ),
      updateTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}update_time'],
      ),
      editedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}edited_at'],
      ),
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $MemosTable createAlias(String alias) {
    return $MemosTable(attachedDatabase, alias);
  }
}

class MemosRow extends DataClass implements Insertable<MemosRow> {
  final String accountId;
  final String uid;

  /// Memo state wire name: NORMAL / ARCHIVED / DELETED.
  final String state;
  final String content;
  final String visibility;
  final bool pinned;

  /// JSON-encoded list of server-known attachments.
  final String attachments;

  /// Set when the intended attachment set diverged from the server and a
  /// push must replay `setMemoAttachments`.
  final bool attachmentsDirty;
  final DateTime? createTime;

  /// Server-side update time, used for conflict detection.
  final DateTime? updateTime;

  /// When the local (offline) edit was made; null once synced.
  final DateTime? editedAt;
  final String syncState;
  final DateTime? syncedAt;
  const MemosRow({
    required this.accountId,
    required this.uid,
    required this.state,
    required this.content,
    required this.visibility,
    required this.pinned,
    required this.attachments,
    required this.attachmentsDirty,
    this.createTime,
    this.updateTime,
    this.editedAt,
    required this.syncState,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['uid'] = Variable<String>(uid);
    map['state'] = Variable<String>(state);
    map['content'] = Variable<String>(content);
    map['visibility'] = Variable<String>(visibility);
    map['pinned'] = Variable<bool>(pinned);
    map['attachments'] = Variable<String>(attachments);
    map['attachments_dirty'] = Variable<bool>(attachmentsDirty);
    if (!nullToAbsent || createTime != null) {
      map['create_time'] = Variable<DateTime>(createTime);
    }
    if (!nullToAbsent || updateTime != null) {
      map['update_time'] = Variable<DateTime>(updateTime);
    }
    if (!nullToAbsent || editedAt != null) {
      map['edited_at'] = Variable<DateTime>(editedAt);
    }
    map['sync_state'] = Variable<String>(syncState);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  MemosCompanion toCompanion(bool nullToAbsent) {
    return MemosCompanion(
      accountId: Value(accountId),
      uid: Value(uid),
      state: Value(state),
      content: Value(content),
      visibility: Value(visibility),
      pinned: Value(pinned),
      attachments: Value(attachments),
      attachmentsDirty: Value(attachmentsDirty),
      createTime: createTime == null && nullToAbsent
          ? const Value.absent()
          : Value(createTime),
      updateTime: updateTime == null && nullToAbsent
          ? const Value.absent()
          : Value(updateTime),
      editedAt: editedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(editedAt),
      syncState: Value(syncState),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory MemosRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemosRow(
      accountId: serializer.fromJson<String>(json['accountId']),
      uid: serializer.fromJson<String>(json['uid']),
      state: serializer.fromJson<String>(json['state']),
      content: serializer.fromJson<String>(json['content']),
      visibility: serializer.fromJson<String>(json['visibility']),
      pinned: serializer.fromJson<bool>(json['pinned']),
      attachments: serializer.fromJson<String>(json['attachments']),
      attachmentsDirty: serializer.fromJson<bool>(json['attachmentsDirty']),
      createTime: serializer.fromJson<DateTime?>(json['createTime']),
      updateTime: serializer.fromJson<DateTime?>(json['updateTime']),
      editedAt: serializer.fromJson<DateTime?>(json['editedAt']),
      syncState: serializer.fromJson<String>(json['syncState']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'uid': serializer.toJson<String>(uid),
      'state': serializer.toJson<String>(state),
      'content': serializer.toJson<String>(content),
      'visibility': serializer.toJson<String>(visibility),
      'pinned': serializer.toJson<bool>(pinned),
      'attachments': serializer.toJson<String>(attachments),
      'attachmentsDirty': serializer.toJson<bool>(attachmentsDirty),
      'createTime': serializer.toJson<DateTime?>(createTime),
      'updateTime': serializer.toJson<DateTime?>(updateTime),
      'editedAt': serializer.toJson<DateTime?>(editedAt),
      'syncState': serializer.toJson<String>(syncState),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  MemosRow copyWith({
    String? accountId,
    String? uid,
    String? state,
    String? content,
    String? visibility,
    bool? pinned,
    String? attachments,
    bool? attachmentsDirty,
    Value<DateTime?> createTime = const Value.absent(),
    Value<DateTime?> updateTime = const Value.absent(),
    Value<DateTime?> editedAt = const Value.absent(),
    String? syncState,
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => MemosRow(
    accountId: accountId ?? this.accountId,
    uid: uid ?? this.uid,
    state: state ?? this.state,
    content: content ?? this.content,
    visibility: visibility ?? this.visibility,
    pinned: pinned ?? this.pinned,
    attachments: attachments ?? this.attachments,
    attachmentsDirty: attachmentsDirty ?? this.attachmentsDirty,
    createTime: createTime.present ? createTime.value : this.createTime,
    updateTime: updateTime.present ? updateTime.value : this.updateTime,
    editedAt: editedAt.present ? editedAt.value : this.editedAt,
    syncState: syncState ?? this.syncState,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  MemosRow copyWithCompanion(MemosCompanion data) {
    return MemosRow(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      uid: data.uid.present ? data.uid.value : this.uid,
      state: data.state.present ? data.state.value : this.state,
      content: data.content.present ? data.content.value : this.content,
      visibility: data.visibility.present
          ? data.visibility.value
          : this.visibility,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      attachments: data.attachments.present
          ? data.attachments.value
          : this.attachments,
      attachmentsDirty: data.attachmentsDirty.present
          ? data.attachmentsDirty.value
          : this.attachmentsDirty,
      createTime: data.createTime.present
          ? data.createTime.value
          : this.createTime,
      updateTime: data.updateTime.present
          ? data.updateTime.value
          : this.updateTime,
      editedAt: data.editedAt.present ? data.editedAt.value : this.editedAt,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemosRow(')
          ..write('accountId: $accountId, ')
          ..write('uid: $uid, ')
          ..write('state: $state, ')
          ..write('content: $content, ')
          ..write('visibility: $visibility, ')
          ..write('pinned: $pinned, ')
          ..write('attachments: $attachments, ')
          ..write('attachmentsDirty: $attachmentsDirty, ')
          ..write('createTime: $createTime, ')
          ..write('updateTime: $updateTime, ')
          ..write('editedAt: $editedAt, ')
          ..write('syncState: $syncState, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    accountId,
    uid,
    state,
    content,
    visibility,
    pinned,
    attachments,
    attachmentsDirty,
    createTime,
    updateTime,
    editedAt,
    syncState,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemosRow &&
          other.accountId == this.accountId &&
          other.uid == this.uid &&
          other.state == this.state &&
          other.content == this.content &&
          other.visibility == this.visibility &&
          other.pinned == this.pinned &&
          other.attachments == this.attachments &&
          other.attachmentsDirty == this.attachmentsDirty &&
          other.createTime == this.createTime &&
          other.updateTime == this.updateTime &&
          other.editedAt == this.editedAt &&
          other.syncState == this.syncState &&
          other.syncedAt == this.syncedAt);
}

class MemosCompanion extends UpdateCompanion<MemosRow> {
  final Value<String> accountId;
  final Value<String> uid;
  final Value<String> state;
  final Value<String> content;
  final Value<String> visibility;
  final Value<bool> pinned;
  final Value<String> attachments;
  final Value<bool> attachmentsDirty;
  final Value<DateTime?> createTime;
  final Value<DateTime?> updateTime;
  final Value<DateTime?> editedAt;
  final Value<String> syncState;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const MemosCompanion({
    this.accountId = const Value.absent(),
    this.uid = const Value.absent(),
    this.state = const Value.absent(),
    this.content = const Value.absent(),
    this.visibility = const Value.absent(),
    this.pinned = const Value.absent(),
    this.attachments = const Value.absent(),
    this.attachmentsDirty = const Value.absent(),
    this.createTime = const Value.absent(),
    this.updateTime = const Value.absent(),
    this.editedAt = const Value.absent(),
    this.syncState = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemosCompanion.insert({
    required String accountId,
    required String uid,
    this.state = const Value.absent(),
    required String content,
    this.visibility = const Value.absent(),
    this.pinned = const Value.absent(),
    this.attachments = const Value.absent(),
    this.attachmentsDirty = const Value.absent(),
    this.createTime = const Value.absent(),
    this.updateTime = const Value.absent(),
    this.editedAt = const Value.absent(),
    this.syncState = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       uid = Value(uid),
       content = Value(content);
  static Insertable<MemosRow> custom({
    Expression<String>? accountId,
    Expression<String>? uid,
    Expression<String>? state,
    Expression<String>? content,
    Expression<String>? visibility,
    Expression<bool>? pinned,
    Expression<String>? attachments,
    Expression<bool>? attachmentsDirty,
    Expression<DateTime>? createTime,
    Expression<DateTime>? updateTime,
    Expression<DateTime>? editedAt,
    Expression<String>? syncState,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (uid != null) 'uid': uid,
      if (state != null) 'state': state,
      if (content != null) 'content': content,
      if (visibility != null) 'visibility': visibility,
      if (pinned != null) 'pinned': pinned,
      if (attachments != null) 'attachments': attachments,
      if (attachmentsDirty != null) 'attachments_dirty': attachmentsDirty,
      if (createTime != null) 'create_time': createTime,
      if (updateTime != null) 'update_time': updateTime,
      if (editedAt != null) 'edited_at': editedAt,
      if (syncState != null) 'sync_state': syncState,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemosCompanion copyWith({
    Value<String>? accountId,
    Value<String>? uid,
    Value<String>? state,
    Value<String>? content,
    Value<String>? visibility,
    Value<bool>? pinned,
    Value<String>? attachments,
    Value<bool>? attachmentsDirty,
    Value<DateTime?>? createTime,
    Value<DateTime?>? updateTime,
    Value<DateTime?>? editedAt,
    Value<String>? syncState,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return MemosCompanion(
      accountId: accountId ?? this.accountId,
      uid: uid ?? this.uid,
      state: state ?? this.state,
      content: content ?? this.content,
      visibility: visibility ?? this.visibility,
      pinned: pinned ?? this.pinned,
      attachments: attachments ?? this.attachments,
      attachmentsDirty: attachmentsDirty ?? this.attachmentsDirty,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
      editedAt: editedAt ?? this.editedAt,
      syncState: syncState ?? this.syncState,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (uid.present) {
      map['uid'] = Variable<String>(uid.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (visibility.present) {
      map['visibility'] = Variable<String>(visibility.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (attachments.present) {
      map['attachments'] = Variable<String>(attachments.value);
    }
    if (attachmentsDirty.present) {
      map['attachments_dirty'] = Variable<bool>(attachmentsDirty.value);
    }
    if (createTime.present) {
      map['create_time'] = Variable<DateTime>(createTime.value);
    }
    if (updateTime.present) {
      map['update_time'] = Variable<DateTime>(updateTime.value);
    }
    if (editedAt.present) {
      map['edited_at'] = Variable<DateTime>(editedAt.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemosCompanion(')
          ..write('accountId: $accountId, ')
          ..write('uid: $uid, ')
          ..write('state: $state, ')
          ..write('content: $content, ')
          ..write('visibility: $visibility, ')
          ..write('pinned: $pinned, ')
          ..write('attachments: $attachments, ')
          ..write('attachmentsDirty: $attachmentsDirty, ')
          ..write('createTime: $createTime, ')
          ..write('updateTime: $updateTime, ')
          ..write('editedAt: $editedAt, ')
          ..write('syncState: $syncState, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemoTagsTable extends MemoTags with TableInfo<$MemoTagsTable, MemoTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memoUidMeta = const VerificationMeta(
    'memoUid',
  );
  @override
  late final GeneratedColumn<String> memoUid = GeneratedColumn<String>(
    'memo_uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [accountId, memoUid, tag];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memo_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemoTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('memo_uid')) {
      context.handle(
        _memoUidMeta,
        memoUid.isAcceptableOrUnknown(data['memo_uid']!, _memoUidMeta),
      );
    } else if (isInserting) {
      context.missing(_memoUidMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, memoUid, tag};
  @override
  MemoTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemoTag(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      memoUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memo_uid'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
    );
  }

  @override
  $MemoTagsTable createAlias(String alias) {
    return $MemoTagsTable(attachedDatabase, alias);
  }
}

class MemoTag extends DataClass implements Insertable<MemoTag> {
  final String accountId;
  final String memoUid;
  final String tag;
  const MemoTag({
    required this.accountId,
    required this.memoUid,
    required this.tag,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['memo_uid'] = Variable<String>(memoUid);
    map['tag'] = Variable<String>(tag);
    return map;
  }

  MemoTagsCompanion toCompanion(bool nullToAbsent) {
    return MemoTagsCompanion(
      accountId: Value(accountId),
      memoUid: Value(memoUid),
      tag: Value(tag),
    );
  }

  factory MemoTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemoTag(
      accountId: serializer.fromJson<String>(json['accountId']),
      memoUid: serializer.fromJson<String>(json['memoUid']),
      tag: serializer.fromJson<String>(json['tag']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'memoUid': serializer.toJson<String>(memoUid),
      'tag': serializer.toJson<String>(tag),
    };
  }

  MemoTag copyWith({String? accountId, String? memoUid, String? tag}) =>
      MemoTag(
        accountId: accountId ?? this.accountId,
        memoUid: memoUid ?? this.memoUid,
        tag: tag ?? this.tag,
      );
  MemoTag copyWithCompanion(MemoTagsCompanion data) {
    return MemoTag(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      memoUid: data.memoUid.present ? data.memoUid.value : this.memoUid,
      tag: data.tag.present ? data.tag.value : this.tag,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoTag(')
          ..write('accountId: $accountId, ')
          ..write('memoUid: $memoUid, ')
          ..write('tag: $tag')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(accountId, memoUid, tag);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoTag &&
          other.accountId == this.accountId &&
          other.memoUid == this.memoUid &&
          other.tag == this.tag);
}

class MemoTagsCompanion extends UpdateCompanion<MemoTag> {
  final Value<String> accountId;
  final Value<String> memoUid;
  final Value<String> tag;
  final Value<int> rowid;
  const MemoTagsCompanion({
    this.accountId = const Value.absent(),
    this.memoUid = const Value.absent(),
    this.tag = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemoTagsCompanion.insert({
    required String accountId,
    required String memoUid,
    required String tag,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       memoUid = Value(memoUid),
       tag = Value(tag);
  static Insertable<MemoTag> custom({
    Expression<String>? accountId,
    Expression<String>? memoUid,
    Expression<String>? tag,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (memoUid != null) 'memo_uid': memoUid,
      if (tag != null) 'tag': tag,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemoTagsCompanion copyWith({
    Value<String>? accountId,
    Value<String>? memoUid,
    Value<String>? tag,
    Value<int>? rowid,
  }) {
    return MemoTagsCompanion(
      accountId: accountId ?? this.accountId,
      memoUid: memoUid ?? this.memoUid,
      tag: tag ?? this.tag,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (memoUid.present) {
      map['memo_uid'] = Variable<String>(memoUid.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoTagsCompanion(')
          ..write('accountId: $accountId, ')
          ..write('memoUid: $memoUid, ')
          ..write('tag: $tag, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingAttachmentsTable extends PendingAttachments
    with TableInfo<$PendingAttachmentsTable, PendingAttachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingAttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memoUidMeta = const VerificationMeta(
    'memoUid',
  );
  @override
  late final GeneratedColumn<String> memoUid = GeneratedColumn<String>(
    'memo_uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filenameMeta = const VerificationMeta(
    'filename',
  );
  @override
  late final GeneratedColumn<String> filename = GeneratedColumn<String>(
    'filename',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    memoUid,
    filename,
    mimeType,
    localPath,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingAttachment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('memo_uid')) {
      context.handle(
        _memoUidMeta,
        memoUid.isAcceptableOrUnknown(data['memo_uid']!, _memoUidMeta),
      );
    } else if (isInserting) {
      context.missing(_memoUidMeta);
    }
    if (data.containsKey('filename')) {
      context.handle(
        _filenameMeta,
        filename.isAcceptableOrUnknown(data['filename']!, _filenameMeta),
      );
    } else if (isInserting) {
      context.missing(_filenameMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingAttachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingAttachment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      memoUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memo_uid'],
      )!,
      filename: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filename'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $PendingAttachmentsTable createAlias(String alias) {
    return $PendingAttachmentsTable(attachedDatabase, alias);
  }
}

class PendingAttachment extends DataClass
    implements Insertable<PendingAttachment> {
  final String id;
  final String accountId;
  final String memoUid;
  final String filename;
  final String mimeType;
  final String localPath;
  final int sortOrder;
  const PendingAttachment({
    required this.id,
    required this.accountId,
    required this.memoUid,
    required this.filename,
    required this.mimeType,
    required this.localPath,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    map['memo_uid'] = Variable<String>(memoUid);
    map['filename'] = Variable<String>(filename);
    map['mime_type'] = Variable<String>(mimeType);
    map['local_path'] = Variable<String>(localPath);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  PendingAttachmentsCompanion toCompanion(bool nullToAbsent) {
    return PendingAttachmentsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      memoUid: Value(memoUid),
      filename: Value(filename),
      mimeType: Value(mimeType),
      localPath: Value(localPath),
      sortOrder: Value(sortOrder),
    );
  }

  factory PendingAttachment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingAttachment(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      memoUid: serializer.fromJson<String>(json['memoUid']),
      filename: serializer.fromJson<String>(json['filename']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      localPath: serializer.fromJson<String>(json['localPath']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'memoUid': serializer.toJson<String>(memoUid),
      'filename': serializer.toJson<String>(filename),
      'mimeType': serializer.toJson<String>(mimeType),
      'localPath': serializer.toJson<String>(localPath),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  PendingAttachment copyWith({
    String? id,
    String? accountId,
    String? memoUid,
    String? filename,
    String? mimeType,
    String? localPath,
    int? sortOrder,
  }) => PendingAttachment(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    memoUid: memoUid ?? this.memoUid,
    filename: filename ?? this.filename,
    mimeType: mimeType ?? this.mimeType,
    localPath: localPath ?? this.localPath,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  PendingAttachment copyWithCompanion(PendingAttachmentsCompanion data) {
    return PendingAttachment(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      memoUid: data.memoUid.present ? data.memoUid.value : this.memoUid,
      filename: data.filename.present ? data.filename.value : this.filename,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingAttachment(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('memoUid: $memoUid, ')
          ..write('filename: $filename, ')
          ..write('mimeType: $mimeType, ')
          ..write('localPath: $localPath, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    memoUid,
    filename,
    mimeType,
    localPath,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingAttachment &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.memoUid == this.memoUid &&
          other.filename == this.filename &&
          other.mimeType == this.mimeType &&
          other.localPath == this.localPath &&
          other.sortOrder == this.sortOrder);
}

class PendingAttachmentsCompanion extends UpdateCompanion<PendingAttachment> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<String> memoUid;
  final Value<String> filename;
  final Value<String> mimeType;
  final Value<String> localPath;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const PendingAttachmentsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.memoUid = const Value.absent(),
    this.filename = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.localPath = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingAttachmentsCompanion.insert({
    required String id,
    required String accountId,
    required String memoUid,
    required String filename,
    required String mimeType,
    required String localPath,
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       memoUid = Value(memoUid),
       filename = Value(filename),
       mimeType = Value(mimeType),
       localPath = Value(localPath);
  static Insertable<PendingAttachment> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? memoUid,
    Expression<String>? filename,
    Expression<String>? mimeType,
    Expression<String>? localPath,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (memoUid != null) 'memo_uid': memoUid,
      if (filename != null) 'filename': filename,
      if (mimeType != null) 'mime_type': mimeType,
      if (localPath != null) 'local_path': localPath,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingAttachmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<String>? memoUid,
    Value<String>? filename,
    Value<String>? mimeType,
    Value<String>? localPath,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return PendingAttachmentsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      memoUid: memoUid ?? this.memoUid,
      filename: filename ?? this.filename,
      mimeType: mimeType ?? this.mimeType,
      localPath: localPath ?? this.localPath,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (memoUid.present) {
      map['memo_uid'] = Variable<String>(memoUid.value);
    }
    if (filename.present) {
      map['filename'] = Variable<String>(filename.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingAttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('memoUid: $memoUid, ')
          ..write('filename: $filename, ')
          ..write('mimeType: $mimeType, ')
          ..write('localPath: $localPath, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncMetaTable extends SyncMeta
    with TableInfo<$SyncMetaTable, SyncMetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSyncAtMeta = const VerificationMeta(
    'lastSyncAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncAt = GeneratedColumn<DateTime>(
    'last_sync_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastResultMeta = const VerificationMeta(
    'lastResult',
  );
  @override
  late final GeneratedColumn<String> lastResult = GeneratedColumn<String>(
    'last_result',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [accountId, lastSyncAt, lastResult];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('last_sync_at')) {
      context.handle(
        _lastSyncAtMeta,
        lastSyncAt.isAcceptableOrUnknown(
          data['last_sync_at']!,
          _lastSyncAtMeta,
        ),
      );
    }
    if (data.containsKey('last_result')) {
      context.handle(
        _lastResultMeta,
        lastResult.isAcceptableOrUnknown(data['last_result']!, _lastResultMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId};
  @override
  SyncMetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetaRow(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      lastSyncAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_sync_at'],
      ),
      lastResult: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_result'],
      )!,
    );
  }

  @override
  $SyncMetaTable createAlias(String alias) {
    return $SyncMetaTable(attachedDatabase, alias);
  }
}

class SyncMetaRow extends DataClass implements Insertable<SyncMetaRow> {
  final String accountId;
  final DateTime? lastSyncAt;
  final String lastResult;
  const SyncMetaRow({
    required this.accountId,
    this.lastSyncAt,
    required this.lastResult,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    if (!nullToAbsent || lastSyncAt != null) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt);
    }
    map['last_result'] = Variable<String>(lastResult);
    return map;
  }

  SyncMetaCompanion toCompanion(bool nullToAbsent) {
    return SyncMetaCompanion(
      accountId: Value(accountId),
      lastSyncAt: lastSyncAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncAt),
      lastResult: Value(lastResult),
    );
  }

  factory SyncMetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetaRow(
      accountId: serializer.fromJson<String>(json['accountId']),
      lastSyncAt: serializer.fromJson<DateTime?>(json['lastSyncAt']),
      lastResult: serializer.fromJson<String>(json['lastResult']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'lastSyncAt': serializer.toJson<DateTime?>(lastSyncAt),
      'lastResult': serializer.toJson<String>(lastResult),
    };
  }

  SyncMetaRow copyWith({
    String? accountId,
    Value<DateTime?> lastSyncAt = const Value.absent(),
    String? lastResult,
  }) => SyncMetaRow(
    accountId: accountId ?? this.accountId,
    lastSyncAt: lastSyncAt.present ? lastSyncAt.value : this.lastSyncAt,
    lastResult: lastResult ?? this.lastResult,
  );
  SyncMetaRow copyWithCompanion(SyncMetaCompanion data) {
    return SyncMetaRow(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      lastSyncAt: data.lastSyncAt.present
          ? data.lastSyncAt.value
          : this.lastSyncAt,
      lastResult: data.lastResult.present
          ? data.lastResult.value
          : this.lastResult,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaRow(')
          ..write('accountId: $accountId, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('lastResult: $lastResult')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(accountId, lastSyncAt, lastResult);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetaRow &&
          other.accountId == this.accountId &&
          other.lastSyncAt == this.lastSyncAt &&
          other.lastResult == this.lastResult);
}

class SyncMetaCompanion extends UpdateCompanion<SyncMetaRow> {
  final Value<String> accountId;
  final Value<DateTime?> lastSyncAt;
  final Value<String> lastResult;
  final Value<int> rowid;
  const SyncMetaCompanion({
    this.accountId = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.lastResult = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMetaCompanion.insert({
    required String accountId,
    this.lastSyncAt = const Value.absent(),
    this.lastResult = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId);
  static Insertable<SyncMetaRow> custom({
    Expression<String>? accountId,
    Expression<DateTime>? lastSyncAt,
    Expression<String>? lastResult,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (lastSyncAt != null) 'last_sync_at': lastSyncAt,
      if (lastResult != null) 'last_result': lastResult,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncMetaCompanion copyWith({
    Value<String>? accountId,
    Value<DateTime?>? lastSyncAt,
    Value<String>? lastResult,
    Value<int>? rowid,
  }) {
    return SyncMetaCompanion(
      accountId: accountId ?? this.accountId,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastResult: lastResult ?? this.lastResult,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (lastSyncAt.present) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt.value);
    }
    if (lastResult.present) {
      map['last_result'] = Variable<String>(lastResult.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaCompanion(')
          ..write('accountId: $accountId, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('lastResult: $lastResult, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MemoEmbeddingsTable extends MemoEmbeddings
    with TableInfo<$MemoEmbeddingsTable, MemoEmbeddingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemoEmbeddingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memoUidMeta = const VerificationMeta(
    'memoUid',
  );
  @override
  late final GeneratedColumn<String> memoUid = GeneratedColumn<String>(
    'memo_uid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<int> contentHash = GeneratedColumn<int>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vectorMeta = const VerificationMeta('vector');
  @override
  late final GeneratedColumn<Uint8List> vector = GeneratedColumn<Uint8List>(
    'vector',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _embeddedAtMeta = const VerificationMeta(
    'embeddedAt',
  );
  @override
  late final GeneratedColumn<DateTime> embeddedAt = GeneratedColumn<DateTime>(
    'embedded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    accountId,
    memoUid,
    model,
    contentHash,
    vector,
    embeddedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memo_embeddings';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemoEmbeddingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('memo_uid')) {
      context.handle(
        _memoUidMeta,
        memoUid.isAcceptableOrUnknown(data['memo_uid']!, _memoUidMeta),
      );
    } else if (isInserting) {
      context.missing(_memoUidMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    if (data.containsKey('vector')) {
      context.handle(
        _vectorMeta,
        vector.isAcceptableOrUnknown(data['vector']!, _vectorMeta),
      );
    } else if (isInserting) {
      context.missing(_vectorMeta);
    }
    if (data.containsKey('embedded_at')) {
      context.handle(
        _embeddedAtMeta,
        embeddedAt.isAcceptableOrUnknown(data['embedded_at']!, _embeddedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_embeddedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId, memoUid, model};
  @override
  MemoEmbeddingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemoEmbeddingsRow(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      memoUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memo_uid'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}content_hash'],
      )!,
      vector: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}vector'],
      )!,
      embeddedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}embedded_at'],
      )!,
    );
  }

  @override
  $MemoEmbeddingsTable createAlias(String alias) {
    return $MemoEmbeddingsTable(attachedDatabase, alias);
  }
}

class MemoEmbeddingsRow extends DataClass
    implements Insertable<MemoEmbeddingsRow> {
  final String accountId;
  final String memoUid;
  final String model;
  final int contentHash;
  final Uint8List vector;
  final DateTime embeddedAt;
  const MemoEmbeddingsRow({
    required this.accountId,
    required this.memoUid,
    required this.model,
    required this.contentHash,
    required this.vector,
    required this.embeddedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['memo_uid'] = Variable<String>(memoUid);
    map['model'] = Variable<String>(model);
    map['content_hash'] = Variable<int>(contentHash);
    map['vector'] = Variable<Uint8List>(vector);
    map['embedded_at'] = Variable<DateTime>(embeddedAt);
    return map;
  }

  MemoEmbeddingsCompanion toCompanion(bool nullToAbsent) {
    return MemoEmbeddingsCompanion(
      accountId: Value(accountId),
      memoUid: Value(memoUid),
      model: Value(model),
      contentHash: Value(contentHash),
      vector: Value(vector),
      embeddedAt: Value(embeddedAt),
    );
  }

  factory MemoEmbeddingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemoEmbeddingsRow(
      accountId: serializer.fromJson<String>(json['accountId']),
      memoUid: serializer.fromJson<String>(json['memoUid']),
      model: serializer.fromJson<String>(json['model']),
      contentHash: serializer.fromJson<int>(json['contentHash']),
      vector: serializer.fromJson<Uint8List>(json['vector']),
      embeddedAt: serializer.fromJson<DateTime>(json['embeddedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'memoUid': serializer.toJson<String>(memoUid),
      'model': serializer.toJson<String>(model),
      'contentHash': serializer.toJson<int>(contentHash),
      'vector': serializer.toJson<Uint8List>(vector),
      'embeddedAt': serializer.toJson<DateTime>(embeddedAt),
    };
  }

  MemoEmbeddingsRow copyWith({
    String? accountId,
    String? memoUid,
    String? model,
    int? contentHash,
    Uint8List? vector,
    DateTime? embeddedAt,
  }) => MemoEmbeddingsRow(
    accountId: accountId ?? this.accountId,
    memoUid: memoUid ?? this.memoUid,
    model: model ?? this.model,
    contentHash: contentHash ?? this.contentHash,
    vector: vector ?? this.vector,
    embeddedAt: embeddedAt ?? this.embeddedAt,
  );
  MemoEmbeddingsRow copyWithCompanion(MemoEmbeddingsCompanion data) {
    return MemoEmbeddingsRow(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      memoUid: data.memoUid.present ? data.memoUid.value : this.memoUid,
      model: data.model.present ? data.model.value : this.model,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      vector: data.vector.present ? data.vector.value : this.vector,
      embeddedAt: data.embeddedAt.present
          ? data.embeddedAt.value
          : this.embeddedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoEmbeddingsRow(')
          ..write('accountId: $accountId, ')
          ..write('memoUid: $memoUid, ')
          ..write('model: $model, ')
          ..write('contentHash: $contentHash, ')
          ..write('vector: $vector, ')
          ..write('embeddedAt: $embeddedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    accountId,
    memoUid,
    model,
    contentHash,
    $driftBlobEquality.hash(vector),
    embeddedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoEmbeddingsRow &&
          other.accountId == this.accountId &&
          other.memoUid == this.memoUid &&
          other.model == this.model &&
          other.contentHash == this.contentHash &&
          $driftBlobEquality.equals(other.vector, this.vector) &&
          other.embeddedAt == this.embeddedAt);
}

class MemoEmbeddingsCompanion extends UpdateCompanion<MemoEmbeddingsRow> {
  final Value<String> accountId;
  final Value<String> memoUid;
  final Value<String> model;
  final Value<int> contentHash;
  final Value<Uint8List> vector;
  final Value<DateTime> embeddedAt;
  final Value<int> rowid;
  const MemoEmbeddingsCompanion({
    this.accountId = const Value.absent(),
    this.memoUid = const Value.absent(),
    this.model = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.vector = const Value.absent(),
    this.embeddedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemoEmbeddingsCompanion.insert({
    required String accountId,
    required String memoUid,
    required String model,
    required int contentHash,
    required Uint8List vector,
    required DateTime embeddedAt,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       memoUid = Value(memoUid),
       model = Value(model),
       contentHash = Value(contentHash),
       vector = Value(vector),
       embeddedAt = Value(embeddedAt);
  static Insertable<MemoEmbeddingsRow> custom({
    Expression<String>? accountId,
    Expression<String>? memoUid,
    Expression<String>? model,
    Expression<int>? contentHash,
    Expression<Uint8List>? vector,
    Expression<DateTime>? embeddedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (memoUid != null) 'memo_uid': memoUid,
      if (model != null) 'model': model,
      if (contentHash != null) 'content_hash': contentHash,
      if (vector != null) 'vector': vector,
      if (embeddedAt != null) 'embedded_at': embeddedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemoEmbeddingsCompanion copyWith({
    Value<String>? accountId,
    Value<String>? memoUid,
    Value<String>? model,
    Value<int>? contentHash,
    Value<Uint8List>? vector,
    Value<DateTime>? embeddedAt,
    Value<int>? rowid,
  }) {
    return MemoEmbeddingsCompanion(
      accountId: accountId ?? this.accountId,
      memoUid: memoUid ?? this.memoUid,
      model: model ?? this.model,
      contentHash: contentHash ?? this.contentHash,
      vector: vector ?? this.vector,
      embeddedAt: embeddedAt ?? this.embeddedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (memoUid.present) {
      map['memo_uid'] = Variable<String>(memoUid.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<int>(contentHash.value);
    }
    if (vector.present) {
      map['vector'] = Variable<Uint8List>(vector.value);
    }
    if (embeddedAt.present) {
      map['embedded_at'] = Variable<DateTime>(embeddedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoEmbeddingsCompanion(')
          ..write('accountId: $accountId, ')
          ..write('memoUid: $memoUid, ')
          ..write('model: $model, ')
          ..write('contentHash: $contentHash, ')
          ..write('vector: $vector, ')
          ..write('embeddedAt: $embeddedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MemosTable memos = $MemosTable(this);
  late final $MemoTagsTable memoTags = $MemoTagsTable(this);
  late final $PendingAttachmentsTable pendingAttachments =
      $PendingAttachmentsTable(this);
  late final $SyncMetaTable syncMeta = $SyncMetaTable(this);
  late final $MemoEmbeddingsTable memoEmbeddings = $MemoEmbeddingsTable(this);
  late final Index idxMemosList = Index(
    'idx_memos_list',
    'CREATE INDEX idx_memos_list ON memos (account_id, state, pinned, create_time)',
  );
  late final Index idxMemoTagsTag = Index(
    'idx_memo_tags_tag',
    'CREATE INDEX idx_memo_tags_tag ON memo_tags (account_id, tag)',
  );
  late final Index idxMemoEmbeddingsAccount = Index(
    'idx_memo_embeddings_account',
    'CREATE INDEX idx_memo_embeddings_account ON memo_embeddings (account_id, model)',
  );
  late final MemoDao memoDao = MemoDao(this as AppDatabase);
  late final EmbeddingDao embeddingDao = EmbeddingDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    memos,
    memoTags,
    pendingAttachments,
    syncMeta,
    memoEmbeddings,
    idxMemosList,
    idxMemoTagsTag,
    idxMemoEmbeddingsAccount,
  ];
}

typedef $$MemosTableCreateCompanionBuilder =
    MemosCompanion Function({
      required String accountId,
      required String uid,
      Value<String> state,
      required String content,
      Value<String> visibility,
      Value<bool> pinned,
      Value<String> attachments,
      Value<bool> attachmentsDirty,
      Value<DateTime?> createTime,
      Value<DateTime?> updateTime,
      Value<DateTime?> editedAt,
      Value<String> syncState,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });
typedef $$MemosTableUpdateCompanionBuilder =
    MemosCompanion Function({
      Value<String> accountId,
      Value<String> uid,
      Value<String> state,
      Value<String> content,
      Value<String> visibility,
      Value<bool> pinned,
      Value<String> attachments,
      Value<bool> attachmentsDirty,
      Value<DateTime?> createTime,
      Value<DateTime?> updateTime,
      Value<DateTime?> editedAt,
      Value<String> syncState,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });

class $$MemosTableFilterComposer extends Composer<_$AppDatabase, $MemosTable> {
  $$MemosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get attachmentsDirty => $composableBuilder(
    column: $table.attachmentsDirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createTime => $composableBuilder(
    column: $table.createTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updateTime => $composableBuilder(
    column: $table.updateTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get editedAt => $composableBuilder(
    column: $table.editedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MemosTableOrderingComposer
    extends Composer<_$AppDatabase, $MemosTable> {
  $$MemosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uid => $composableBuilder(
    column: $table.uid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get attachmentsDirty => $composableBuilder(
    column: $table.attachmentsDirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createTime => $composableBuilder(
    column: $table.createTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updateTime => $composableBuilder(
    column: $table.updateTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get editedAt => $composableBuilder(
    column: $table.editedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MemosTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemosTable> {
  $$MemosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get uid =>
      $composableBuilder(column: $table.uid, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<String> get attachments => $composableBuilder(
    column: $table.attachments,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get attachmentsDirty => $composableBuilder(
    column: $table.attachmentsDirty,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createTime => $composableBuilder(
    column: $table.createTime,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updateTime => $composableBuilder(
    column: $table.updateTime,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get editedAt =>
      $composableBuilder(column: $table.editedAt, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$MemosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemosTable,
          MemosRow,
          $$MemosTableFilterComposer,
          $$MemosTableOrderingComposer,
          $$MemosTableAnnotationComposer,
          $$MemosTableCreateCompanionBuilder,
          $$MemosTableUpdateCompanionBuilder,
          (MemosRow, BaseReferences<_$AppDatabase, $MemosTable, MemosRow>),
          MemosRow,
          PrefetchHooks Function()
        > {
  $$MemosTableTableManager(_$AppDatabase db, $MemosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> uid = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> visibility = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<String> attachments = const Value.absent(),
                Value<bool> attachmentsDirty = const Value.absent(),
                Value<DateTime?> createTime = const Value.absent(),
                Value<DateTime?> updateTime = const Value.absent(),
                Value<DateTime?> editedAt = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemosCompanion(
                accountId: accountId,
                uid: uid,
                state: state,
                content: content,
                visibility: visibility,
                pinned: pinned,
                attachments: attachments,
                attachmentsDirty: attachmentsDirty,
                createTime: createTime,
                updateTime: updateTime,
                editedAt: editedAt,
                syncState: syncState,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String uid,
                Value<String> state = const Value.absent(),
                required String content,
                Value<String> visibility = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<String> attachments = const Value.absent(),
                Value<bool> attachmentsDirty = const Value.absent(),
                Value<DateTime?> createTime = const Value.absent(),
                Value<DateTime?> updateTime = const Value.absent(),
                Value<DateTime?> editedAt = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemosCompanion.insert(
                accountId: accountId,
                uid: uid,
                state: state,
                content: content,
                visibility: visibility,
                pinned: pinned,
                attachments: attachments,
                attachmentsDirty: attachmentsDirty,
                createTime: createTime,
                updateTime: updateTime,
                editedAt: editedAt,
                syncState: syncState,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MemosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemosTable,
      MemosRow,
      $$MemosTableFilterComposer,
      $$MemosTableOrderingComposer,
      $$MemosTableAnnotationComposer,
      $$MemosTableCreateCompanionBuilder,
      $$MemosTableUpdateCompanionBuilder,
      (MemosRow, BaseReferences<_$AppDatabase, $MemosTable, MemosRow>),
      MemosRow,
      PrefetchHooks Function()
    >;
typedef $$MemoTagsTableCreateCompanionBuilder =
    MemoTagsCompanion Function({
      required String accountId,
      required String memoUid,
      required String tag,
      Value<int> rowid,
    });
typedef $$MemoTagsTableUpdateCompanionBuilder =
    MemoTagsCompanion Function({
      Value<String> accountId,
      Value<String> memoUid,
      Value<String> tag,
      Value<int> rowid,
    });

class $$MemoTagsTableFilterComposer
    extends Composer<_$AppDatabase, $MemoTagsTable> {
  $$MemoTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memoUid => $composableBuilder(
    column: $table.memoUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MemoTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $MemoTagsTable> {
  $$MemoTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memoUid => $composableBuilder(
    column: $table.memoUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MemoTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemoTagsTable> {
  $$MemoTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get memoUid =>
      $composableBuilder(column: $table.memoUid, builder: (column) => column);

  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);
}

class $$MemoTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemoTagsTable,
          MemoTag,
          $$MemoTagsTableFilterComposer,
          $$MemoTagsTableOrderingComposer,
          $$MemoTagsTableAnnotationComposer,
          $$MemoTagsTableCreateCompanionBuilder,
          $$MemoTagsTableUpdateCompanionBuilder,
          (MemoTag, BaseReferences<_$AppDatabase, $MemoTagsTable, MemoTag>),
          MemoTag,
          PrefetchHooks Function()
        > {
  $$MemoTagsTableTableManager(_$AppDatabase db, $MemoTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemoTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemoTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemoTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> memoUid = const Value.absent(),
                Value<String> tag = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoTagsCompanion(
                accountId: accountId,
                memoUid: memoUid,
                tag: tag,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String memoUid,
                required String tag,
                Value<int> rowid = const Value.absent(),
              }) => MemoTagsCompanion.insert(
                accountId: accountId,
                memoUid: memoUid,
                tag: tag,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MemoTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemoTagsTable,
      MemoTag,
      $$MemoTagsTableFilterComposer,
      $$MemoTagsTableOrderingComposer,
      $$MemoTagsTableAnnotationComposer,
      $$MemoTagsTableCreateCompanionBuilder,
      $$MemoTagsTableUpdateCompanionBuilder,
      (MemoTag, BaseReferences<_$AppDatabase, $MemoTagsTable, MemoTag>),
      MemoTag,
      PrefetchHooks Function()
    >;
typedef $$PendingAttachmentsTableCreateCompanionBuilder =
    PendingAttachmentsCompanion Function({
      required String id,
      required String accountId,
      required String memoUid,
      required String filename,
      required String mimeType,
      required String localPath,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$PendingAttachmentsTableUpdateCompanionBuilder =
    PendingAttachmentsCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<String> memoUid,
      Value<String> filename,
      Value<String> mimeType,
      Value<String> localPath,
      Value<int> sortOrder,
      Value<int> rowid,
    });

class $$PendingAttachmentsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingAttachmentsTable> {
  $$PendingAttachmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memoUid => $composableBuilder(
    column: $table.memoUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filename => $composableBuilder(
    column: $table.filename,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingAttachmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingAttachmentsTable> {
  $$PendingAttachmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memoUid => $composableBuilder(
    column: $table.memoUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filename => $composableBuilder(
    column: $table.filename,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingAttachmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingAttachmentsTable> {
  $$PendingAttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get memoUid =>
      $composableBuilder(column: $table.memoUid, builder: (column) => column);

  GeneratedColumn<String> get filename =>
      $composableBuilder(column: $table.filename, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$PendingAttachmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingAttachmentsTable,
          PendingAttachment,
          $$PendingAttachmentsTableFilterComposer,
          $$PendingAttachmentsTableOrderingComposer,
          $$PendingAttachmentsTableAnnotationComposer,
          $$PendingAttachmentsTableCreateCompanionBuilder,
          $$PendingAttachmentsTableUpdateCompanionBuilder,
          (
            PendingAttachment,
            BaseReferences<
              _$AppDatabase,
              $PendingAttachmentsTable,
              PendingAttachment
            >,
          ),
          PendingAttachment,
          PrefetchHooks Function()
        > {
  $$PendingAttachmentsTableTableManager(
    _$AppDatabase db,
    $PendingAttachmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingAttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingAttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingAttachmentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> memoUid = const Value.absent(),
                Value<String> filename = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<String> localPath = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingAttachmentsCompanion(
                id: id,
                accountId: accountId,
                memoUid: memoUid,
                filename: filename,
                mimeType: mimeType,
                localPath: localPath,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                required String memoUid,
                required String filename,
                required String mimeType,
                required String localPath,
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingAttachmentsCompanion.insert(
                id: id,
                accountId: accountId,
                memoUid: memoUid,
                filename: filename,
                mimeType: mimeType,
                localPath: localPath,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingAttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingAttachmentsTable,
      PendingAttachment,
      $$PendingAttachmentsTableFilterComposer,
      $$PendingAttachmentsTableOrderingComposer,
      $$PendingAttachmentsTableAnnotationComposer,
      $$PendingAttachmentsTableCreateCompanionBuilder,
      $$PendingAttachmentsTableUpdateCompanionBuilder,
      (
        PendingAttachment,
        BaseReferences<
          _$AppDatabase,
          $PendingAttachmentsTable,
          PendingAttachment
        >,
      ),
      PendingAttachment,
      PrefetchHooks Function()
    >;
typedef $$SyncMetaTableCreateCompanionBuilder =
    SyncMetaCompanion Function({
      required String accountId,
      Value<DateTime?> lastSyncAt,
      Value<String> lastResult,
      Value<int> rowid,
    });
typedef $$SyncMetaTableUpdateCompanionBuilder =
    SyncMetaCompanion Function({
      Value<String> accountId,
      Value<DateTime?> lastSyncAt,
      Value<String> lastResult,
      Value<int> rowid,
    });

class $$SyncMetaTableFilterComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastResult => $composableBuilder(
    column: $table.lastResult,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncMetaTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastResult => $composableBuilder(
    column: $table.lastResult,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncMetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncMetaTable> {
  $$SyncMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastResult => $composableBuilder(
    column: $table.lastResult,
    builder: (column) => column,
  );
}

class $$SyncMetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncMetaTable,
          SyncMetaRow,
          $$SyncMetaTableFilterComposer,
          $$SyncMetaTableOrderingComposer,
          $$SyncMetaTableAnnotationComposer,
          $$SyncMetaTableCreateCompanionBuilder,
          $$SyncMetaTableUpdateCompanionBuilder,
          (
            SyncMetaRow,
            BaseReferences<_$AppDatabase, $SyncMetaTable, SyncMetaRow>,
          ),
          SyncMetaRow,
          PrefetchHooks Function()
        > {
  $$SyncMetaTableTableManager(_$AppDatabase db, $SyncMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<DateTime?> lastSyncAt = const Value.absent(),
                Value<String> lastResult = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncMetaCompanion(
                accountId: accountId,
                lastSyncAt: lastSyncAt,
                lastResult: lastResult,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                Value<DateTime?> lastSyncAt = const Value.absent(),
                Value<String> lastResult = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncMetaCompanion.insert(
                accountId: accountId,
                lastSyncAt: lastSyncAt,
                lastResult: lastResult,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncMetaTable,
      SyncMetaRow,
      $$SyncMetaTableFilterComposer,
      $$SyncMetaTableOrderingComposer,
      $$SyncMetaTableAnnotationComposer,
      $$SyncMetaTableCreateCompanionBuilder,
      $$SyncMetaTableUpdateCompanionBuilder,
      (SyncMetaRow, BaseReferences<_$AppDatabase, $SyncMetaTable, SyncMetaRow>),
      SyncMetaRow,
      PrefetchHooks Function()
    >;
typedef $$MemoEmbeddingsTableCreateCompanionBuilder =
    MemoEmbeddingsCompanion Function({
      required String accountId,
      required String memoUid,
      required String model,
      required int contentHash,
      required Uint8List vector,
      required DateTime embeddedAt,
      Value<int> rowid,
    });
typedef $$MemoEmbeddingsTableUpdateCompanionBuilder =
    MemoEmbeddingsCompanion Function({
      Value<String> accountId,
      Value<String> memoUid,
      Value<String> model,
      Value<int> contentHash,
      Value<Uint8List> vector,
      Value<DateTime> embeddedAt,
      Value<int> rowid,
    });

class $$MemoEmbeddingsTableFilterComposer
    extends Composer<_$AppDatabase, $MemoEmbeddingsTable> {
  $$MemoEmbeddingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memoUid => $composableBuilder(
    column: $table.memoUid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get vector => $composableBuilder(
    column: $table.vector,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get embeddedAt => $composableBuilder(
    column: $table.embeddedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MemoEmbeddingsTableOrderingComposer
    extends Composer<_$AppDatabase, $MemoEmbeddingsTable> {
  $$MemoEmbeddingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memoUid => $composableBuilder(
    column: $table.memoUid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get vector => $composableBuilder(
    column: $table.vector,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get embeddedAt => $composableBuilder(
    column: $table.embeddedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MemoEmbeddingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemoEmbeddingsTable> {
  $$MemoEmbeddingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get memoUid =>
      $composableBuilder(column: $table.memoUid, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<int> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get vector =>
      $composableBuilder(column: $table.vector, builder: (column) => column);

  GeneratedColumn<DateTime> get embeddedAt => $composableBuilder(
    column: $table.embeddedAt,
    builder: (column) => column,
  );
}

class $$MemoEmbeddingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MemoEmbeddingsTable,
          MemoEmbeddingsRow,
          $$MemoEmbeddingsTableFilterComposer,
          $$MemoEmbeddingsTableOrderingComposer,
          $$MemoEmbeddingsTableAnnotationComposer,
          $$MemoEmbeddingsTableCreateCompanionBuilder,
          $$MemoEmbeddingsTableUpdateCompanionBuilder,
          (
            MemoEmbeddingsRow,
            BaseReferences<
              _$AppDatabase,
              $MemoEmbeddingsTable,
              MemoEmbeddingsRow
            >,
          ),
          MemoEmbeddingsRow,
          PrefetchHooks Function()
        > {
  $$MemoEmbeddingsTableTableManager(
    _$AppDatabase db,
    $MemoEmbeddingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemoEmbeddingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemoEmbeddingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemoEmbeddingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> memoUid = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<int> contentHash = const Value.absent(),
                Value<Uint8List> vector = const Value.absent(),
                Value<DateTime> embeddedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoEmbeddingsCompanion(
                accountId: accountId,
                memoUid: memoUid,
                model: model,
                contentHash: contentHash,
                vector: vector,
                embeddedAt: embeddedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String memoUid,
                required String model,
                required int contentHash,
                required Uint8List vector,
                required DateTime embeddedAt,
                Value<int> rowid = const Value.absent(),
              }) => MemoEmbeddingsCompanion.insert(
                accountId: accountId,
                memoUid: memoUid,
                model: model,
                contentHash: contentHash,
                vector: vector,
                embeddedAt: embeddedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MemoEmbeddingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MemoEmbeddingsTable,
      MemoEmbeddingsRow,
      $$MemoEmbeddingsTableFilterComposer,
      $$MemoEmbeddingsTableOrderingComposer,
      $$MemoEmbeddingsTableAnnotationComposer,
      $$MemoEmbeddingsTableCreateCompanionBuilder,
      $$MemoEmbeddingsTableUpdateCompanionBuilder,
      (
        MemoEmbeddingsRow,
        BaseReferences<_$AppDatabase, $MemoEmbeddingsTable, MemoEmbeddingsRow>,
      ),
      MemoEmbeddingsRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MemosTableTableManager get memos =>
      $$MemosTableTableManager(_db, _db.memos);
  $$MemoTagsTableTableManager get memoTags =>
      $$MemoTagsTableTableManager(_db, _db.memoTags);
  $$PendingAttachmentsTableTableManager get pendingAttachments =>
      $$PendingAttachmentsTableTableManager(_db, _db.pendingAttachments);
  $$SyncMetaTableTableManager get syncMeta =>
      $$SyncMetaTableTableManager(_db, _db.syncMeta);
  $$MemoEmbeddingsTableTableManager get memoEmbeddings =>
      $$MemoEmbeddingsTableTableManager(_db, _db.memoEmbeddings);
}
