import 'package:cached_network_image/cached_network_image.dart';
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
    return SizedBox(
      height: images.length == 1 ? 200 : 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final attachment = images[index];
          final url = repo.attachmentUrl(attachment, thumbnail: true);
          return GestureDetector(
            onTap: () => onTap?.call(images, index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: images.length == 1 ? double.infinity : 130,
                child: AttachmentImage(url: url, headers: repo.authHeaders),
              ),
            ),
          );
        },
      ),
    );
  }
}
