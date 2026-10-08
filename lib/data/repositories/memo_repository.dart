import '../api/memos_api.dart';
import '../api/memos_api_client.dart';
import '../models/models.dart';
import 'auth_repository.dart';

/// Facade over [MemosApi] bound to the active [ServerAccount].
class MemoRepository {
  MemoRepository(this.account)
      : _api = MemosApi(
          createMemosDio(baseUrl: account.baseUrl, token: account.token),
          baseUrl: account.baseUrl,
        );

  final ServerAccount account;
  final MemosApi _api;

  String get baseUrl => account.baseUrl;
  Map<String, String> get authHeaders =>
      {'Authorization': 'Bearer ${account.token}'};

  Future<MemoListPage> listMemos({
    int pageSize = 50,
    String pageToken = '',
    String? filter,
  }) =>
      _api.listMemos(pageSize: pageSize, pageToken: pageToken, filter: filter);

  Future<Memo> getMemo(String uid) => _api.getMemo(uid);

  Future<Memo> createMemo({
    required String content,
    required MemoVisibility visibility,
    List<Attachment> attachments = const [],
  }) async {
    final memo = await _api.createMemo(
        content: content, visibility: visibility);
    if (attachments.isNotEmpty) {
      await _api.setMemoAttachments(memo.uid, attachments);
      return memo.copyWith(attachments: attachments);
    }
    return memo;
  }

  Future<Memo> updateMemo(Memo memo) =>
      _api.updateMemo(memo, ['content', 'visibility', 'pinned']);

  /// Replaces the memo's attachment set; pass an empty list to clear.
  Future<void> updateMemoAttachments(String uid, List<Attachment> attachments) =>
      _api.setMemoAttachments(uid, attachments);

  Future<void> deleteMemo(String uid) => _api.deleteMemo(uid);

  Future<Attachment> uploadAttachment({
    required String filename,
    required String mimeType,
    required List<int> bytes,
  }) =>
      _api.createAttachment(
          filename: filename, mimeType: mimeType, bytes: bytes);

  Future<UserStats> userStats() async {
    final username =
        account.user.username.isNotEmpty ? account.user.username : account.user.uid;
    return _api.getUserStats(username);
  }

  /// Absolute URL for an attachment's binary content (bearer-protected).
  String attachmentUrl(Attachment attachment, {bool thumbnail = false}) =>
      attachmentFileUrl(baseUrl, attachment.uid, thumbnail: thumbnail);
}

/// Builds a CEL filter expression for the ListMemos `filter` parameter,
/// combining a free-text query and/or a tag.
String buildMemoFilter({String? query, String? tag}) {
  final parts = <String>[];
  final q = query?.trim() ?? '';
  if (q.isNotEmpty) parts.add('content.contains("${_escapeCel(q)}")');
  final t = tag?.trim() ?? '';
  if (t.isNotEmpty) parts.add('"${_escapeCel(t)}" in tags');
  return parts.join(' && ');
}

String _escapeCel(String value) =>
    value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
