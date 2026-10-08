/// Data models for the Memos v1 API (grpc-gateway JSON, camelCase).
///
/// Parsing is written defensively because self-hosted servers vary between
/// minor versions: unknown/missing fields must never crash the client.
library;

import 'package:flutter/foundation.dart';

/// Memo visibility, serialized as proto enum names.
enum MemoVisibility {
  private('PRIVATE'),
  protected('PROTECTED'),
  public('PUBLIC'),
  space('SPACE');

  const MemoVisibility(this.wireName);
  final String wireName;

  static MemoVisibility fromWire(String? value) => switch (value) {
        'PROTECTED' => MemoVisibility.protected,
        'PUBLIC' => MemoVisibility.public,
        'SPACE' => MemoVisibility.space,
        _ => MemoVisibility.private,
      };
}

enum MemoState {
  normal('NORMAL'),
  archived('ARCHIVED'),
  deleted('DELETED');

  const MemoState(this.wireName);
  final String wireName;

  static MemoState fromWire(String? value) => switch (value) {
        'ARCHIVED' => MemoState.archived,
        'DELETED' => MemoState.deleted,
        _ => MemoState.normal,
      };
}

@immutable
class User {
  const User({
    required this.name,
    this.username = '',
    this.displayName = '',
    this.email = '',
    this.avatarUrl = '',
    this.role = '',
  });

  /// Resource name, e.g. `users/1`.
  final String name;
  final String username;
  final String displayName;
  final String email;
  final String avatarUrl;
  final String role;

  /// Identifier segment of [name] (`users/{id}` -> `{id}`).
  String get uid => name.split('/').last;

  String get shownName {
    final n = displayName.trim();
    if (n.isNotEmpty) return n;
    final u = username.trim();
    if (u.isNotEmpty) return u;
    return uid;
  }

  factory User.fromJson(Map<String, dynamic> json) => User(
        name: json['name'] as String? ?? '',
        username: json['username'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        email: json['email'] as String? ?? '',
        avatarUrl: json['avatarUrl'] as String? ?? '',
        role: json['role'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'username': username,
        'displayName': displayName,
        'email': email,
        'avatarUrl': avatarUrl,
        'role': role,
      };
}

@immutable
class Attachment {
  const Attachment({
    required this.name,
    this.filename = '',
    this.type = '',
    this.size = 0,
    this.externalLink = '',
    this.createTime,
  });

  /// Resource name, e.g. `attachments/abc123`.
  final String name;
  final String filename;
  final String type;
  final int size;
  final String externalLink;

  /// May be null for pending uploads that have no server-side object yet.
  final DateTime? createTime;

  /// Identifier segment of [name] (`attachments/{uid}` -> `{uid}`).
  String get uid => name.split('/').last;

  static final RegExp _imageExtPattern =
      RegExp(r'\.(png|jpe?g|gif|webp|heic|bmp)$');

  bool get isImage =>
      type.startsWith('image/') ||
      (type.isEmpty && _imageExtPattern.hasMatch(filename.toLowerCase()));

  factory Attachment.fromJson(Map<String, dynamic> json) => Attachment(
        name: json['name'] as String? ?? '',
        filename: json['filename'] as String? ?? '',
        type: json['type'] as String? ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
        externalLink: json['externalLink'] as String? ?? '',
        createTime: tryParseTime(json['createTime'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'filename': filename,
        'type': type,
        if (size > 0) 'size': size,
        if (externalLink.isNotEmpty) 'externalLink': externalLink,
      };
}

@immutable
class Memo {
  const Memo({
    required this.name,
    this.state = MemoState.normal,
    this.creator = '',
    this.content = '',
    this.visibility = MemoVisibility.private,
    this.pinned = false,
    this.tags = const [],
    this.attachments = const [],
    this.createTime,
    this.updateTime,
  });

  /// Resource name, e.g. `memos/xyz`.
  final String name;
  final MemoState state;
  final String creator;
  final String content;
  final MemoVisibility visibility;
  final bool pinned;
  final List<String> tags;
  final List<Attachment> attachments;
  final DateTime? createTime;
  final DateTime? updateTime;

  String get uid => name.split('/').last;

  factory Memo.fromJson(Map<String, dynamic> json) => Memo(
        name: json['name'] as String? ?? '',
        state: MemoState.fromWire(json['state'] as String?),
        creator: json['creator'] as String? ?? '',
        content: json['content'] as String? ?? '',
        visibility: MemoVisibility.fromWire(json['visibility'] as String?),
        pinned: json['pinned'] as bool? ?? false,
        tags: (json['tags'] as List<dynamic>? ?? const [])
            .map((e) => e as String)
            .toList(),
        attachments: (json['attachments'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Attachment.fromJson)
            .toList(),
        createTime: tryParseTime(json['createTime'] as String?),
        updateTime: tryParseTime(json['updateTime'] as String?),
      );

  Map<String, dynamic> toCreateJson() => {
        'content': content,
        'visibility': visibility.wireName,
      };

  Map<String, dynamic> toUpdateJson() => {
        'name': name,
        'content': content,
        'visibility': visibility.wireName,
        'pinned': pinned,
        'state': state.wireName,
      };

  Memo copyWith({
    String? content,
    MemoVisibility? visibility,
    bool? pinned,
    MemoState? state,
    List<Attachment>? attachments,
  }) =>
      Memo(
        name: name,
        state: state ?? this.state,
        creator: creator,
        content: content ?? this.content,
        visibility: visibility ?? this.visibility,
        pinned: pinned ?? this.pinned,
        tags: tags,
        attachments: attachments ?? this.attachments,
        createTime: createTime,
        updateTime: updateTime,
      );
}

@immutable
class MemoListPage {
  const MemoListPage({required this.memos, this.nextPageToken = ''});

  final List<Memo> memos;

  /// Empty when there are no further pages.
  final String nextPageToken;
}

@immutable
class UserStats {
  const UserStats({this.tagCounts = const {}});

  final Map<String, int> tagCounts;

  factory UserStats.fromJson(Map<String, dynamic> json) {
    final raw = json['tagCount'];
    if (raw is Map<String, dynamic>) {
      return UserStats(
        tagCounts: raw.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0)),
      );
    }
    return const UserStats();
  }
}

@immutable
class InstanceStatus {
  const InstanceStatus({this.version = '', this.host = ''});

  final String version;
  final String host;

  factory InstanceStatus.fromJson(Map<String, dynamic> json) =>
      InstanceStatus(
        version: json['version'] as String? ?? '',
        host: json['host'] as String? ?? '',
      );
}

DateTime? tryParseTime(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
