import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Opens the memo list filtered by [tag].
///
/// Tag values are nested paths (e.g. `Inbox/22`) and may contain characters
/// reserved in URI path segments (`/`, `?`, `#`, `%`), so they must be
/// percent-encoded; interpolating a raw tag yields an unroutable location
/// (`GoException: no routes for location`).
void pushTagMemos(BuildContext context, String tag) =>
    context.push('/memos/tag/${Uri.encodeComponent(tag)}');

/// Opens the composer with `#tag` prefilled, e.g. from a tag page's FAB.
///
/// The tag rides in a query parameter, so — like [pushTagMemos] — it must be
/// percent-encoded to survive reserved characters (`/`, `?`, `#`, `%`) in
/// nested tag paths.
void pushNewMemoWithTag(BuildContext context, String tag) =>
    context.push('/memos/new?tag=${Uri.encodeComponent(tag)}');
