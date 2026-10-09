import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/image_viewer.dart';
import '../../data/api/memos_api_client.dart';
import '../../data/models/models.dart';
import '../../data/repositories/memo_repository.dart';
import '../../providers/auth_providers.dart';
import '../../providers/memo_providers.dart';

/// Creates a new memo (optionally prefilled with `#[initialTag] `) or edits
/// an existing one ([editingUid]; [initialTag] is ignored then).
class MemoEditorPage extends ConsumerStatefulWidget {
  const MemoEditorPage({super.key, this.editingUid, this.initialTag});

  final String? editingUid;

  /// Tag to prefill the composer with when creating, e.g. from a tag page.
  final String? initialTag;

  @override
  ConsumerState<MemoEditorPage> createState() => _MemoEditorPageState();
}

class _MemoEditorPageState extends ConsumerState<MemoEditorPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  Memo? _editing;
  var _visibility = MemoVisibility.private;
  var _pinned = false;
  List<Attachment> _attachments = [];
  var _loading = false;
  var _saving = false;
  var _uploadingCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.editingUid != null) {
      _loading = true;
      Future.microtask(_loadMemo);
    } else {
      final tag = widget.initialTag?.trim();
      if (tag != null && tag.isNotEmpty) {
        _controller.text = '#$tag ';
        _controller.selection =
            TextSelection.collapsed(offset: _controller.text.length);
      }
    }
    // Rebuild on text *and* caret moves so the tag suggestion row tracks
    // the `#token` under the cursor.
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  /// Known tags ranked for [query]: startsWith matches first, then contains,
  /// each by usage count. An empty query surfaces the most-used tags.
  static const _maxTagSuggestions = 8;

  List<MapEntry<String, int>> _suggestTags(
      String query, Map<String, int> known) {
    final q = query.toLowerCase();
    final starts = <MapEntry<String, int>>[];
    final contains = <MapEntry<String, int>>[];
    known.forEach((tag, count) {
      final lower = tag.toLowerCase();
      if (lower == q) return;
      if (lower.startsWith(q)) {
        starts.add(MapEntry(tag, count));
      } else if (q.isNotEmpty && lower.contains(q)) {
        contains.add(MapEntry(tag, count));
      }
    });
    int byUsage(MapEntry<String, int> a, MapEntry<String, int> b) =>
        b.value.compareTo(a.value);
    starts.sort(byUsage);
    contains.sort(byUsage);
    return [...starts, ...contains].take(_maxTagSuggestions).toList();
  }

  /// Replaces the `#query` token under the caret with the picked [tag].
  void _applyTagSuggestion(String tag) {
    final token = tagTokenAt(_controller.text, _controller.selection.baseOffset);
    if (token == null) return;
    final replacement = '#$tag ';
    _controller.value = TextEditingValue(
      text: _controller.text.replaceRange(token.start, token.end, replacement),
      selection:
          TextSelection.collapsed(offset: token.start + replacement.length),
    );
    _focusNode.requestFocus();
  }

  Future<void> _loadMemo() async {
    try {
      final memo = await ref.read(memoRepositoryProvider)!.getMemo(widget.editingUid!);
      if (!mounted) return;
      setState(() {
        _editing = memo;
        _controller.text = memo.content;
        _visibility = memo.visibility;
        _pinned = memo.pinned;
        _attachments = List.of(memo.attachments);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final l10n = AppLocalizations.of(context)!;
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 2560,
          maxHeight: 2560);
      if (picked == null) return;
      setState(() => _uploadingCount++);
      final bytes = await picked.readAsBytes();
      final repo = ref.read(memoRepositoryProvider)!;
      final mime = picked.mimeType ?? _guessMime(picked.name);
      final attachment = await repo.uploadAttachment(
        filename: picked.name,
        mimeType: mime,
        bytes: bytes,
      );
      setState(() => _attachments.add(attachment));
    } catch (e) {
      _snack('${l10n.uploadFailed}: ${_messageOf(e)}');
    } finally {
      if (mounted) setState(() => _uploadingCount--);
    }
  }

  String _guessMime(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  void _insertMarkdown(String before, [String after = '']) {
    final selection = _controller.selection;
    final text = _controller.text;
    if (!selection.isValid) return;
    final start = selection.start;
    final end = selection.end;
    final selected = text.substring(start, end);
    final inserted = '$before$selected$after';
    _controller.value = TextEditingValue(
      text: text.replaceRange(start, end, inserted),
      selection: TextSelection.collapsed(offset: start + before.length + selected.length),
    );
    _focusNode.requestFocus();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final content = _controller.text.trim();
    if (content.isEmpty && _attachments.isEmpty) {
      _snack(l10n.contentEmpty);
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(memoRepositoryProvider)!;
      if (_editing == null) {
        final created = await repo.createMemo(
          content: content,
          visibility: _visibility,
          attachments: _attachments,
        );
        ref.read(memoMutationProvider.notifier).upsert(created);
      } else {
        final updated = await repo.updateMemo(
          _editing!.copyWith(
            content: content,
            visibility: _visibility,
            pinned: _pinned,
            attachments: _attachments,
          ),
        );
        if (!setEquals(_attachments.map((a) => a.uid).toSet(),
            _editing!.attachments.map((a) => a.uid).toSet())) {
          await repo.updateMemoAttachments(updated.uid, _attachments);
        }
        ref
            .read(memoMutationProvider.notifier)
            .upsert(updated.copyWith(attachments: _attachments));
      }
      ref.invalidate(memoInsightsProvider);
      if (mounted) context.pop();
    } catch (e) {
      _snack('${l10n.save}: ${_messageOf(e)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tags = extractTags(_controller.text).toList()..sort();

    // Only fetch the tag directory once the user starts typing a `#tag`.
    final token =
        tagTokenAt(_controller.text, _controller.selection.baseOffset);
    final suggestions = token == null
        ? const <MapEntry<String, int>>[]
        : _suggestTags(
            token.query,
            ref.watch(userTagsProvider).valueOrNull ??
                const <String, int>{},
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing == null ? l10n.newMemo : l10n.editMemo),
        actions: [
          IconButton(
            tooltip: l10n.addImage,
            onPressed: _uploadingCount > 0 ? null : _pickImage,
            icon: _uploadingCount > 0
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.image_outlined),
          ),
          if (_editing != null)
            IconButton(
              tooltip: l10n.pin,
              onPressed: () => setState(() => _pinned = !_pinned),
              icon: Icon(
                _pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                color: _pinned ? theme.colorScheme.primary : null,
              ),
            ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.save),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          keyboardType: TextInputType.multiline,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            filled: false,
                            hintText: l10n.memoContentHint,
                          ),
                        ),
                      ),
                    ),
                    if (_attachments.isNotEmpty)
                      SizedBox(
                        height: 92,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          itemCount: _attachments.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final attachment = _attachments[index];
                            return _AttachmentThumb(
                              attachment: attachment,
                              repo: ref.watch(memoRepositoryProvider)!,
                              onRemove: () =>
                                  setState(() => _attachments.removeAt(index)),
                            );
                          },
                        ),
                      ),
                    if (tags.isNotEmpty)
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          children: [
                            for (final tag in tags)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Chip(
                                  label: Text('#$tag'),
                                  visualDensity: VisualDensity.compact,
                                  onDeleted: () => _removeTag(tag),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (suggestions.isNotEmpty)
                      SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          itemCount: suggestions.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 6),
                          itemBuilder: (context, index) {
                            final tag = suggestions[index].key;
                            return ActionChip(
                              label: Text('#$tag'),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _applyTagSuggestion(tag),
                            );
                          },
                        ),
                      ),
                    _Toolbar(onInsert: _insertMarkdown),
                    _VisibilityBar(
                      visibility: _visibility,
                      onChanged: (v) => setState(() => _visibility = v),
                    ),
                  ],
                ),
    );
  }

  void _removeTag(String tag) {
    final pattern = RegExp(
        '(^|\\s)#${RegExp.escape(tag)}' r'([\s.,!?)，。！？]|$)');
    _controller.text =
        _controller.text.replaceAllMapped(pattern, (m) => m.group(1) ?? '');
    setState(() {});
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

String _messageOf(Object e) => asMemosApiError(e)?.message ?? e.toString();

class _AttachmentThumb extends StatelessWidget {
  const _AttachmentThumb({
    required this.attachment,
    required this.repo,
    required this.onRemove,
  });

  final Attachment attachment;
  final MemoRepository repo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        GestureDetector(
          onTap: () => showAttachmentViewer(
            context,
            images: [attachment],
            repo: repo,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 80,
              height: 80,
              child: attachment.isImage
                  ? Image.network(
                      repo.attachmentUrl(attachment, thumbnail: true),
                      headers: repo.authHeaders,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.description_outlined),
                      ),
                    )
                  : ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.description_outlined),
                    ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.inverseSurface,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(3),
              child: Icon(Icons.close,
                  size: 13, color: theme.colorScheme.onInverseSurface),
            ),
          ),
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.onInsert});

  final void Function(String before, [String after]) onInsert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: .5)),
        ),
      ),
      child: SizedBox(
        height: 46,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _btn(context, Icons.format_bold_rounded, () => onInsert('**', '**')),
            _btn(context, Icons.format_italic_rounded, () => onInsert('*', '*')),
            _btn(context, Icons.format_strikethrough_rounded,
                () => onInsert('~~', '~~')),
            _btn(context, Icons.format_list_bulleted_rounded,
                () => onInsert('\n- ')),
            _btn(context, Icons.format_list_numbered_rounded,
                () => onInsert('\n1. ')),
            _btn(context, Icons.check_box_outlined, () => onInsert('\n- [ ] ')),
            _btn(context, Icons.code_rounded, () => onInsert('`', '`')),
            _btn(context, Icons.link_rounded, () => onInsert('[', '](https://)')),
            _btn(context, Icons.tag_rounded, () => onInsert('#')),
          ],
        ),
      ),
    );
  }

  Widget _btn(BuildContext context, IconData icon, VoidCallback onTap) =>
      IconButton(
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, size: 20),
        onPressed: onTap,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
}

class _VisibilityBar extends StatelessWidget {
  const _VisibilityBar({required this.visibility, required this.onChanged});

  final MemoVisibility visibility;
  final ValueChanged<MemoVisibility> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final options = {
      MemoVisibility.private: (Icons.lock_outline, l10n.visibilityPrivate),
      MemoVisibility.protected: (Icons.group_outlined, l10n.visibilityProtected),
      MemoVisibility.public: (Icons.public, l10n.visibilityPublic),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: Row(
        children: [
          Icon(Icons.visibility_outlined,
              size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: SegmentedButton<MemoVisibility>(
              selected: {visibility},
              onSelectionChanged: (s) => onChanged(s.first),
              segments: [
                for (final entry in options.entries)
                  ButtonSegment(
                    value: entry.key,
                    icon: Icon(entry.value.$1, size: 16),
                    label: Text(entry.value.$2,
                        style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
