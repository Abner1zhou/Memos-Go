import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Thin wrapper over the record package for memo voice input. Produces
/// AAC-LC `.m4a` files in the OS temp directory.
class VoiceRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  String? _path;

  /// Checks (and requests on first call) microphone permission.
  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Starts recording to a new temp file.
  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    _path = path;
  }

  /// Stops recording and returns the file path (null when not recording).
  Future<String?> stop() async {
    final stopped = await _recorder.stop();
    return stopped ?? _path;
  }

  /// Stops any in-flight recording and deletes the temp file.
  Future<void> cancel() async {
    try {
      await _recorder.cancel();
    } catch (_) {
      // Not recording anymore — nothing to stop.
    }
    final path = _path;
    _path = null;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  void dispose() => _recorder.dispose();
}
