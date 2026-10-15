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
}
