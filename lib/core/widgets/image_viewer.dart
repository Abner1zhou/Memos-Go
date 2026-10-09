import 'package:flutter/material.dart';

import '../../data/models/models.dart';
import '../../data/repositories/memo_repository.dart';
import 'attachment_image.dart';

/// Opens a fullscreen, zoomable viewer for [images] starting at
/// [initialIndex]. Images load in full size (no thumbnail) with bearer auth.
Future<void> showAttachmentViewer(
  BuildContext context, {
  required List<Attachment> images,
  required MemoRepository repo,
  int initialIndex = 0,
}) {
  if (images.isEmpty) return Future.value();
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => AttachmentViewerPage(
        images: images,
        repo: repo,
        initialIndex: initialIndex.clamp(0, images.length - 1),
      ),
    ),
  );
}

/// Fullscreen image viewer: swipe to switch images, pinch or double-tap to
/// zoom, tap anywhere to close.
class AttachmentViewerPage extends StatefulWidget {
  const AttachmentViewerPage({
    super.key,
    required this.images,
    required this.repo,
    this.initialIndex = 0,
  });

  final List<Attachment> images;
  final MemoRepository repo;
  final int initialIndex;

  @override
  State<AttachmentViewerPage> createState() => _AttachmentViewerPageState();
}

class _AttachmentViewerPageState extends State<AttachmentViewerPage> {
  late final PageController _pageController =
      PageController(initialPage: widget.initialIndex);
  late var _index = widget.initialIndex;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final many = widget.images.length > 1;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => _ZoomableImage(
              url: widget.repo.attachmentUrl(widget.images[i]),
              headers: widget.repo.authHeaders,
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context)
                      .modalBarrierDismissLabel,
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                if (many)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Text(
                      '${_index + 1} / ${widget.images.length}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single image that pans when zoomed (below 1x the horizontal drag is
/// left to the surrounding PageView).
class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({required this.url, required this.headers});

  final String url;
  final Map<String, String> headers;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final _transformation = TransformationController();
  TapDownDetails? _doubleTapDetails;

  static const _doubleTapScale = 2.5;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transformation.addListener(_onTransformationChanged);
  }

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  void _onTransformationChanged() {
    final zoomed = _transformation.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  void _handleDoubleTap() {
    final position = _doubleTapDetails?.localPosition;
    if (_zoomed || position == null) {
      _transformation.value = Matrix4.identity();
    } else {
      _transformation.value = Matrix4.identity()
        ..translateByDouble(position.dx, position.dy, 0, 1)
        ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1)
        ..translateByDouble(-position.dx, -position.dy, 0, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _transformation,
      panEnabled: _zoomed,
      maxScale: 6,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        onDoubleTapDown: (details) => _doubleTapDetails = details,
        onDoubleTap: _handleDoubleTap,
        child: Center(
          child: AttachmentImage(
            url: widget.url,
            headers: widget.headers,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
