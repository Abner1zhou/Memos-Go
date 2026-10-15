import '../../data/api/llm_api.dart';
import '../../l10n/generated/app_localizations.dart';

/// Maps an LLM-layer error to a localized, user-facing message: transport
/// classes get dedicated copy, everything else falls back to the API
/// message (which already carries the HTTP status) or `toString()`.
String llmErrorMessage(AppLocalizations l10n, Object error) {
  final api = asLlmApiError(error);
  if (api == null) return error.toString();
  return switch (api.kind) {
    LlmErrorKind.timeout => l10n.llmErrTimeout,
    LlmErrorKind.unreachable => l10n.llmErrUnreachable,
    LlmErrorKind.auth => l10n.llmErrAuth,
    _ => api.message,
  };
}
