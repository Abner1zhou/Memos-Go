import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

/// In-memory [FlutterSecureStoragePlatform] fake. Assign to
/// `FlutterSecureStoragePlatform.instance` in `setUp` and restore the
/// [MethodChannelFlutterSecureStorage] in `tearDown`.
class FakeSecureStorage extends FlutterSecureStoragePlatform {
  final values = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    Map<String, String> options = const {},
  }) async =>
      values[key];

  @override
  Future<Map<String, String>> readAll({
    Map<String, String> options = const {},
  }) async =>
      Map.of(values);

  @override
  Future<void> write({
    required String key,
    required String? value,
    Map<String, String> options = const {},
  }) async {
    if (value != null) values[key] = value;
  }

  @override
  Future<bool> containsKey({
    required String key,
    Map<String, String> options = const {},
  }) async =>
      values.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    Map<String, String> options = const {},
  }) async =>
      values.remove(key);

  @override
  Future<void> deleteAll({Map<String, String> options = const {}}) async =>
      values.clear();

  @override
  Future<SecureStorageUpgradeStatus> checkUpgradeStatus({
    Map<String, String> options = const {},
  }) async =>
      const SecureStorageUpgradeStatus(
          state: SecureStorageUpgradeState.unknown);
}
