import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class MemorySecretStore implements SecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class PlatformSecretStore implements SecretStore {
  PlatformSecretStore() : _storage = const FlutterSecureStorage();
  final FlutterSecureStorage _storage;

  String _safe(String key) => key.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

  @override
  Future<String?> read(String key) => _storage.read(key: _safe(key));

  @override
  Future<void> write(String key, String value) => _storage.write(key: _safe(key), value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: _safe(key));
}
