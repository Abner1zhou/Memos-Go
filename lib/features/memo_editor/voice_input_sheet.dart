import 'dart:async';

import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';

import '../../core/audio/voice_recorder.dart';

/// Modal sheet that records a voice note with [recorder]. Recording starts
/// immediately; confirming pops with the recorded file path, while cancel or
/// any blocked dismissal (back gesture, scrim tap) deletes the temp file and
/// pops with null.
Future<String?> showVoiceRecordingSheet(
    BuildContext context, VoiceRecorder recorder) {
  return showModalBottomSheet<String>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (sheetContext) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        recorder.cancel();
        Navigator.pop(sheetContext, null);
      },
      child: _VoiceRecordingSheet(recorder: recorder),
    ),
  );
}

class _VoiceRecordingSheet extends StatefulWidget {
  const _VoiceRecordingSheet({required this.recorder});

  final VoiceRecorder recorder;

  @override
  State<_VoiceRecordingSheet> createState() => _VoiceRecordingSheetState();
}

class _VoiceRecordingSheetState extends State<_VoiceRecordingSheet> {
  final _stopwatch = Stopwatch();
  Timer? _timer;
  var _stopping = false;

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    widget.recorder.start().catchError((_) {
      // Microphone became unavailable while opening the sheet.
      if (mounted) Navigator.pop(context, null);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_stopping) return;
    setState(() => _stopping = true);
    _timer?.cancel();
    _stopwatch.stop();
    final path = await widget.recorder.stop();
    if (mounted) Navigator.pop(context, path);
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    _stopwatch.stop();
    await widget.recorder.cancel();
    if (mounted) Navigator.pop(context, null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final minutes = (_stopwatch.elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final seconds =
        (_stopwatch.elapsed.inSeconds % 60).toString().padLeft(2, '0');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PulsingDot(color: theme.colorScheme.error),
                const SizedBox(width: 10),
                Text(
                  '${l10n.recording} $minutes:$seconds',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cancel,
                    child: Text(l10n.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _stopping ? null : _confirm,
                    child: _stopping
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.finishRecording),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(
        scale: Tween(begin: 0.6, end: 1.3).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        ),
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
        ),
      );
}
