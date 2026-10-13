import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

/// Inline play/pause control for an audio attachment, streaming through the
/// bearer-protected file endpoint. [compact] renders the square variant used
/// by the editor's attachment strip instead of the full-width detail row.
class AudioAttachmentTile extends StatefulWidget {
  const AudioAttachmentTile({
    super.key,
    required this.url,
    required this.headers,
    this.compact = false,
  });

  final String url;
  final Map<String, String> headers;
  final bool compact;

  @override
  State<AudioAttachmentTile> createState() => _AudioAttachmentTileState();
}

class _AudioAttachmentTileState extends State<AudioAttachmentTile> {
  final _player = AudioPlayer();
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(widget.url), headers: widget.headers),
      );
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_failed) {
      final child = Icon(Icons.error_outline,
          color: theme.colorScheme.onSurfaceVariant);
      return widget.compact
          ? ColoredBox(
              color: theme.colorScheme.surfaceContainerHighest, child: child)
          : child;
    }

    if (widget.compact) {
      return ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest,
        child: StreamBuilder<PlayerState>(
          stream: _player.playerStateStream,
          builder: (context, snap) {
            final playing = snap.data?.playing ?? false;
            return IconButton(
              icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
              color: theme.colorScheme.onSurfaceVariant,
              onPressed: _toggle,
            );
          },
        ),
      );
    }

    return Row(
      children: [
        StreamBuilder<PlayerState>(
          stream: _player.playerStateStream,
          builder: (context, snap) {
            final playing = snap.data?.playing ?? false;
            return IconButton.filledTonal(
              onPressed: _toggle,
              icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
            );
          },
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              _ProgressBar(player: _player),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.player});

  final AudioPlayer player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, positionSnap) {
        final position = positionSnap.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: player.durationStream,
          builder: (context, durationSnap) {
            final duration = durationSnap.data;
            final total = duration ?? Duration.zero;
            final value = total.inMilliseconds == 0
                ? 0.0
                : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: value),
                const SizedBox(height: 4),
                Text(
                  '${_fmt(position)} / ${duration == null ? '–:––' : _fmt(total)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}
