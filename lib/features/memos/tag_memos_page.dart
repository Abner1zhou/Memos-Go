import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/navigation.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers/auth_providers.dart';
import '../../providers/memo_providers.dart';
import 'memos_page.dart';
import 'voice_memo_capture.dart';

/// Memo feed filtered by a single tag (`#tag`).
class TagMemosPage extends ConsumerStatefulWidget {
  const TagMemosPage({super.key, required this.tag});

  final String tag;

  @override
  ConsumerState<TagMemosPage> createState() => _TagMemosPageState();
}

class _TagMemosPageState extends ConsumerState<TagMemosPage> {
  var _voiceBusy = false;

  /// Long-press on the "+" FAB: record → transcribe → `#tag` memo, no editor.
  Future<void> _quickVoiceMemo() async {
    if (_voiceBusy) return;
    HapticFeedback.mediumImpact();
    setState(() => _voiceBusy = true);
    try {
      await captureVoiceMemo(context, ref, tag: widget.tag);
    } finally {
      if (mounted) setState(() => _voiceBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final query = MemosQuery(tag: widget.tag);
    final list = ref.watch(memosListProvider(query));
    final repo = ref.watch(memoRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text('#${widget.tag}')),
      floatingActionButton: GestureDetector(
        // Long-press starts quick voice capture; taps fall through to the
        // FAB's own onPressed. The hint rides on Semantics because a FAB
        // tooltip registers its own long-press recognizer, which would win
        // the gesture arena over this one.
        onLongPress: _voiceBusy ? null : _quickVoiceMemo,
        child: Semantics(
          label: l10n.newMemoFabTooltip,
          child: FloatingActionButton(
            onPressed: _voiceBusy
                ? null
                : () => pushNewMemoWithTag(context, widget.tag),
            child: _voiceBusy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Icon(Icons.add, size: 30),
          ),
        ),
      ),
      body: MemosFeedBody(query: query, list: list, repo: repo),
    );
  }
}
