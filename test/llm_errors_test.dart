import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/core/utils/llm_errors.dart';
import 'package:memos_go/data/api/llm_api.dart';
import 'package:memos_go/l10n/generated/app_localizations.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('zh'));
  });

  test('kind-based localization', () {
    expect(llmErrorMessage(l10n, const LlmApiException('x', kind: LlmErrorKind.timeout)),
        l10n.llmErrTimeout);
    expect(llmErrorMessage(l10n, const LlmApiException('x', kind: LlmErrorKind.unreachable)),
        l10n.llmErrUnreachable);
    expect(llmErrorMessage(l10n, const LlmApiException('x', kind: LlmErrorKind.auth)),
        l10n.llmErrAuth);
  });

  test('other kinds keep the api message', () {
    expect(llmErrorMessage(l10n, const LlmApiException('HTTP 500 boom')),
        'HTTP 500 boom');
  });

  test('non-llm errors stringify', () {
    expect(llmErrorMessage(l10n, StateError('bad')), contains('bad'));
  });
}
