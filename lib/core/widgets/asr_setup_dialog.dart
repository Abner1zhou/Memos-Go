import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';

/// "ASR not configured" prompt shared by every voice-input entry point
/// (editor mic button, long-press quick capture on the "+" FAB). Offers a
/// jump to the ASR settings page.
Future<void> showAsrSetupDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final goSettings = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.asrNotConfiguredTitle),
      content: Text(l10n.asrNotConfiguredMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.asrGoSettings),
        ),
      ],
    ),
  );
  if (goSettings == true && context.mounted) context.push('/settings/asr');
}
