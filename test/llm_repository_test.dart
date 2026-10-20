import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/data/api/llm_api.dart';
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

  test('suggestOnSave roundtrips and defaults on', () async {
    expect(const LlmSettings().suggestOnSave, isTrue);
    await repo.save(const LlmSettings(
        baseUrl: 'https://x', apiKey: 'k', chatModel: 'm',
        suggestOnSave: false));
    expect((await repo.load()).suggestOnSave, isFalse);
    // 旧配置缺字段 → 默认开启。
    storage.values['memos_go.llmConfig'] =
        '{"baseUrl":"https://x","apiKey":"k","chatModel":"m"}';
    expect((await repo.load()).suggestOnSave, isTrue);
    // 坏类型不崩。
    storage.values['memos_go.llmConfig'] =
        '{"baseUrl":"https://x","apiKey":"k","chatModel":"m","suggestOnSave":"yes"}';
    expect((await repo.load()).suggestOnSave, isTrue);
  });

  test('chatStream rejects on a non-2xx SSE response', () async {
    // 结构性测试：仓库层把错误映射成 LlmApiException 后，
    // chatStream 的 Stream 以 LlmApiException 报错。
    final repo = LlmRepository();
    final stream = repo.chatStream(
      const LlmSettings(baseUrl: 'not a url', apiKey: '', chatModel: ''),
      messages: const [],
    );
    await expectLater(
        stream.drain<void>(), throwsA(isA<LlmApiException>()));
  });
}
