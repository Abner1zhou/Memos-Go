import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/data/repositories/llm_repository.dart';

import 'fake_secure_storage.dart';

void main() {
  late FakeSecureStorage storage;
  late LlmRepository repo;

  setUp(() {
    storage = FakeSecureStorage();
    FlutterSecureStoragePlatform.instance = storage;
    repo = LlmRepository();
  });

  tearDown(() {
    FlutterSecureStoragePlatform.instance =
        MethodChannelFlutterSecureStorage();
  });

  test('roundtrips settings through secure storage', () async {
    await repo.save(const LlmSettings(
      baseUrl: 'https://api.deepseek.com/v1',
      apiKey: 'sk-secret',
      chatModel: 'deepseek-chat',
      embeddingModel: 'text-embedding-3-small',
    ));

    final loaded = await repo.load();
    expect(loaded.baseUrl, 'https://api.deepseek.com/v1');
    expect(loaded.apiKey, 'sk-secret');
    expect(loaded.chatModel, 'deepseek-chat');
    expect(loaded.embeddingModel, 'text-embedding-3-small');
    expect(loaded.isConfigured, isTrue);
    expect(loaded.embeddingsConfigured, isTrue);
    // The API key only ever lands in secure storage.
    expect(storage.values.containsKey('memos_go.llmConfig'), isTrue);
  });

  test('defaults when nothing saved', () async {
    final loaded = await repo.load();
    expect(loaded.isConfigured, isFalse);
    expect(loaded.embeddingsConfigured, isFalse);
  });

  test('corrupt JSON yields defaults instead of crashing', () async {
    storage.values['memos_go.llmConfig'] = '{not json';
    expect((await repo.load()).isConfigured, isFalse);
  });

  test('non-string fields do not crash parsing', () async {
    storage.values['memos_go.llmConfig'] =
        '{"baseUrl": 42, "chatModel": "m", "embeddingModel": []}';
    final loaded = await repo.load();
    expect(loaded.baseUrl, '');
    expect(loaded.chatModel, 'm');
    expect(loaded.embeddingModel, '');
  });

  test('clear removes the stored config', () async {
    await repo.save(
        const LlmSettings(baseUrl: 'https://x', apiKey: 'k', chatModel: 'm'));
    await repo.clear();
    expect((await repo.load()).isConfigured, isFalse);
    expect(storage.values.containsKey('memos_go.llmConfig'), isFalse);
  });

  test('isConfigured requires base URL, key and chat model together', () {
    expect(
        const LlmSettings(baseUrl: 'https://x', apiKey: 'k', chatModel: 'm')
            .isConfigured,
        isTrue);
    expect(
        const LlmSettings(baseUrl: 'https://x', apiKey: 'k', chatModel: '')
            .isConfigured,
        isFalse);
    // Embedding model alone does not make the config usable.
    expect(
        const LlmSettings(
                baseUrl: 'https://x', apiKey: 'k', embeddingModel: 'e')
            .isConfigured,
        isFalse);
  });

  test('copyWith overrides only given fields', () {
    const base = LlmSettings(
        baseUrl: 'https://x', apiKey: 'k', chatModel: 'm');
    expect(base.copyWith(chatModel: 'm2').chatModel, 'm2');
    expect(base.copyWith(chatModel: 'm2').apiKey, 'k');
  });
}
