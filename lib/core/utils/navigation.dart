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
