import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;
import 'package:flutter/material.dart';

import '../../data/models/models.dart';
import '../../data/repositories/memo_repository.dart';

/// Displays an attachment image through the bearer-protected file endpoint.
class AttachmentImage extends StatelessWidget {
  const AttachmentImage({
    super.key,
    required this.url,
    required this.headers,
    this.fit = BoxFit.cover,
  });

  final String url;
  final Map<String, String> headers;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: headers,
      fit: fit,
      // Web's default HtmlImage renderer loads via an <img> element, which
      // cannot send the Authorization header (server then answers 401).
      // HttpGet fetches through the HTTP path with headers instead.
      imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
      placeholder: (_, _) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (_, _, _) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(
          Icons.broken_image_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Horizontal gallery of a memo's image attachments.
class MemoAttachmentsGallery extends StatelessWidget {
  const MemoAttachmentsGallery({
    super.key,
    required this.memo,
    required this.repo,
    this.onTap,
  });

  final Memo memo;
  final MemoRepository repo;
  final void Function(List<Attachment> attachments, int index)? onTap;

  @override
  Widget build(BuildContext context) {
    final images =
        memo.attachments.where((a) => a.isImage && a.name.isNotEmpty).toList();
    if (images.isEmpty) return const SizedBox.shrink();
    // A horizontal ListView gives its children unbounded width, so a single
    // full-width image must be rendered outside the list (double.infinity is
    // only legal under the card's bounded width).
    if (images.length == 1) {
      return _GalleryTile(
        attachment: images.single,
        width: double.infinity,
        height: 200,
        repo: repo,
        onTap: () => onTap?.call(images, 0),
      );
    }
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) => _GalleryTile(
          attachment: images[index],
          width: 130,
          height: 130,
          repo: repo,
          onTap: () => onTap?.call(images, index),
        ),
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    required this.attachment,
    required this.width,
    required this.height,
    required this.repo,
    this.onTap,
  });

  final Attachment attachment;
  final double width;
  final double height;
  final MemoRepository repo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: width,
          height: height,
          child: AttachmentImage(
            url: repo.attachmentUrl(attachment, thumbnail: true),
            headers: repo.authHeaders,
          ),
        ),
      ),
    );
  }
}
