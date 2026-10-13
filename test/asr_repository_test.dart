import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/data/api/asr_api.dart';
import 'package:memos_go/data/repositories/asr_repository.dart';

import 'fake_secure_storage.dart';

void main() {
  late FakeSecureStorage storage;
  late AsrRepository repo;

  setUp(() {
    storage = FakeSecureStorage();
    FlutterSecureStoragePlatform.instance = storage;
    repo = AsrRepository();
  });

  tearDown(() {
    FlutterSecureStoragePlatform.instance =
        MethodChannelFlutterSecureStorage();
  });

  test('roundtrips settings through secure storage', () async {
    await repo.save(const AsrSettings(
      baseUrl: 'https://api.example.com/v1',
      apiKey: 'sk-secret',
      model: 'whisper-1',
      language: 'zh',
      keepAudio: false,
    ));

    final loaded = await repo.load();
    expect(loaded.baseUrl, 'https://api.example.com/v1');
    expect(loaded.apiKey, 'sk-secret');
    expect(loaded.model, 'whisper-1');
    expect(loaded.language, 'zh');
    expect(loaded.keepAudio, isFalse);
    expect(loaded.isConfigured, isTrue);
    // The API key only ever lands in secure storage.
    expect(storage.values.containsKey('memos_go.asrConfig'), isTrue);
  });

  test('defaults when nothing saved', () async {
    final loaded = await repo.load();
    expect(loaded.isConfigured, isFalse);
    expect(loaded.keepAudio, isTrue);
  });

  test('corrupt JSON yields defaults instead of crashing', () async {
    storage.values['memos_go.asrConfig'] = '{not json';
    final loaded = await repo.load();
    expect(loaded.isConfigured, isFalse);
  });

  test('non-string fields do not crash parsing', () async {
    storage.values['memos_go.asrConfig'] =
        '{"baseUrl": 42, "model": "m", "keepAudio": "yes"}';
    final loaded = await repo.load();
    expect(loaded.baseUrl, '');
    expect(loaded.keepAudio, isTrue);
  });

  test('clear removes the stored config', () async {
    await repo.save(
        const AsrSettings(baseUrl: 'https://x', apiKey: 'k', model: 'm'));
    await repo.clear();
    expect((await repo.load()).isConfigured, isFalse);
    expect(storage.values.containsKey('memos_go.asrConfig'), isFalse);
  });

  test('isConfigured requires base URL, key and model together', () {
    expect(
        const AsrSettings(baseUrl: 'https://x', apiKey: 'k', model: 'm')
            .isConfigured,
        isTrue);
    expect(
        const AsrSettings(baseUrl: 'https://x', apiKey: 'k', model: '')
            .isConfigured,
        isFalse);
    expect(
        const AsrSettings(baseUrl: 'https://x', apiKey: '', model: 'm')
            .isConfigured,
        isFalse);
  });

  test('dialect roundtrips and falls back to openai', () async {
    await repo.save(const AsrSettings(
      dialect: AsrDialect.dashscope,
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      apiKey: 'sk-x',
      model: 'qwen3-asr-flash',
    ));
    expect((await repo.load()).dialect, AsrDialect.dashscope);

    await repo.save(const AsrSettings(
      dialect: AsrDialect.dashscopeNative,
      baseUrl: 'https://dashscope.aliyuncs.com',
      apiKey: 'sk-x',
      model: 'qwen3-asr-flash',
    ));
    expect((await repo.load()).dialect, AsrDialect.dashscopeNative);

    // Configs saved before the dialect field existed.
    storage.values['memos_go.asrConfig'] =
        '{"baseUrl":"https://x","apiKey":"k","model":"m"}';
    expect((await repo.load()).dialect, AsrDialect.openai);

    // Unknown persisted value degrades to openai instead of crashing.
    storage.values['memos_go.asrConfig'] =
        '{"dialect":"carrier-pigeon","baseUrl":"https://x","apiKey":"k","model":"m"}';
    expect((await repo.load()).dialect, AsrDialect.openai);
  });
}
