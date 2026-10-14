import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/voice_recorder.dart';
import '../../core/widgets/asr_setup_dialog.dart';
import '../../data/api/asr_api.dart';
import '../../data/api/memos_api_client.dart';
import '../../data/models/models.dart';
import '../../data/repositories/asr_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers/asr_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/memo_providers.dart';
import '../memo_editor/voice_input_sheet.dart';

/// Quick voice capture behind a long-press on the "+" FAB: record a voice
/// note, then create a memo straight from the transcript (prefixed with
/// `#tag` when launched from a tag page) plus the audio attachment when the
/// setting keeps it — no editor round-trip.
Future<void> captureVoiceMemo(
  BuildContext context,
  WidgetRef ref, {
  String? tag,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final asr = ref.read(asrProvider);
  if (!asr.isConfigured) {
    await showAsrSetupDialog(context);
    return;
  }
  final recorder = VoiceRecorder();
  String? path;
  try {
    if (!await recorder.hasPermission()) {
      if (context.mounted) _snack(context, l10n.micPermissionDenied);
      return;
    }
    if (!context.mounted) return;
    path = await showVoiceRecordingSheet(context, recorder);
  } finally {
    recorder.dispose();
  }
  if (path == null || !context.mounted) return;
  await _createMemoFromRecording(context, ref, path, asr, tag);
}

Future<void> _createMemoFromRecording(
  BuildContext context,
  WidgetRef ref,
  String path,
  AsrSettings asr,
  String? tag,
) async {
  final l10n = AppLocalizations.of(context)!;
  // Captured before the first await so later snacks survive unmounting.
  final messenger = ScaffoldMessenger.of(context);
  void snack(String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  final bytes = await File(path).readAsBytes();
  final repo = ref.read(memoRepositoryProvider)!;

  // Keeping the audio and transcribing it are independent: one failing
  // must not lose the other's result (mirrors the editor flow).
  Attachment? audio;
  if (asr.keepAudio) {
    try {
      audio = await repo.uploadAttachment(
        filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
        mimeType: 'audio/mp4',
        bytes: bytes,
      );
    } catch (e) {
      snack('${l10n.uploadFailed}: ${_messageOf(e)}');
    }
  }

  var text = '';
  var transcribeFailed = false;
  try {
    text = (await ref.read(asrRepositoryProvider).transcribe(
          asr,
          bytes: bytes,
          filename: 'voice.m4a',
        ))
        .trim();
  } catch (e) {
    transcribeFailed = true;
    snack('${l10n.transcribeFailed}: ${_messageOf(e)}');
  }

  // With no transcript, an audio-only memo still preserves the recording;
  // with neither there is nothing worth saving.
  if (text.isEmpty && audio == null) {
    if (!transcribeFailed) snack(l10n.voiceMemoEmpty);
    unawaited(_deleteQuietly(File(path)));
    return;
  }

  final cleanTag = tag?.trim();
  // Offline ASR failure degrades to an audio-only memo; a placeholder keeps
  // the content non-empty so a later push is accepted by the server.
  final bodyText = text.isNotEmpty ? text : l10n.voiceMemoUntitled;
  final content =
      (cleanTag == null || cleanTag.isEmpty) ? bodyText : '#$cleanTag $bodyText';
  try {
    final memo = await repo.createMemo(
      content: content,
      visibility: MemoVisibility.private,
      attachments: [?audio],
    );
    ref.read(memoMutationProvider.notifier).upsert(memo);
    ref.invalidate(memoInsightsProvider);
    snack(l10n.voiceMemoSaved);
  } catch (e) {
    snack('${l10n.save}: ${_messageOf(e)}');
  } finally {
    unawaited(_deleteQuietly(File(path)));
  }
}

String _messageOf(Object e) =>
    e is AsrApiException ? e.message : asMemosApiError(e)?.message ?? e.toString();

Future<void> _deleteQuietly(File file) async {
  try {
    await file.delete();
  } catch (_) {
    // Best-effort temp cleanup.
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
