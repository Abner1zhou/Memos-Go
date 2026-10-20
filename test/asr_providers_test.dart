import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/data/repositories/asr_repository.dart';
import 'package:memos_go/providers/asr_providers.dart';

import 'fake_secure_storage.dart';

void main() {
  late FakeSecureStorage storage;

  setUp(() {
    storage = FakeSecureStorage();
    FlutterSecureStoragePlatform.instance = storage;
  });

  tearDown(() {
    FlutterSecureStoragePlatform.instance =
        MethodChannelFlutterSecureStorage();
  });

  test('a save that races the hydration load is not clobbered', () async {
    // Hydration is still in flight when save() runs; the late load must
    // not overwrite the freshly saved state.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(asrProvider.notifier).save(const AsrSettings(
        baseUrl: 'https://x', apiKey: 'k', model: 'm'));
    // Let the stale hydration future complete.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(asrProvider).model, 'm');
  });

  test('a cold-start voice action sees the stored config', () async {
    storage.values['memos_go.asrConfig'] =
        '{"dialect":"openai","baseUrl":"https://x/v1","apiKey":"k",'
        '"model":"m","language":"","keepAudio":true}';
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // A one-shot read still sees the optimistic default while the storage
    // load is in flight — this is why entry points must use readHydrated.
    expect(container.read(asrProvider).isConfigured, isFalse);
    final asr = await container.read(asrProvider.notifier).readHydrated();
    expect(asr.isConfigured, isTrue);
    expect(asr.model, 'm');
  });

  test('readHydrated resolves with defaults when nothing is stored',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final asr = await container.read(asrProvider.notifier).readHydrated();
    expect(asr.isConfigured, isFalse);
  });
}
