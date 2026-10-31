import 'dart:convert';
import 'dart:io';

abstract class Records {
  Future<String?> get(String key);
  Future<void> set(String key, String value);
  Future<void> remove(String key);
  Future<void> removePrefix(String prefix);
}

class MemoryRecords implements Records {
  final Map<String, String> data = {};

  @override
  Future<String?> get(String key) async => data[key];

  @override
  Future<void> set(String key, String value) async => data[key] = value;

  @override
  Future<void> remove(String key) async => data.remove(key);

  @override
  Future<void> removePrefix(String prefix) async => data.removeWhere((k, _) => k.startsWith(prefix));
}

class FileRecords implements Records {
  FileRecords(this.dir);
  final Directory dir;

  String _name(String key) => '${base64Url.encode(utf8.encode(key)).replaceAll('=', '')}.rec';

  File _file(String key) => File('${dir.path}${Platform.pathSeparator}${_name(key)}');

  @override
  Future<String?> get(String key) async {
    try {
      final file = _file(key);
      return await file.exists() ? await file.readAsString() : null;
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> set(String key, String value) async {
    await dir.create(recursive: true);
    final file = _file(key);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(value, flush: true);
    await temp.rename(file.path);
  }

  @override
  Future<void> remove(String key) async {
    final file = _file(key);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> removePrefix(String prefix) async {
    if (!await dir.exists()) return;
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.rec')) continue;
      final name = entity.uri.pathSegments.last;
      final key = _decode(name.substring(0, name.length - 4));
      if (key != null && key.startsWith(prefix)) await entity.delete();
    }
  }

  String? _decode(String stem) {
    try {
      return utf8.decode(base64Url.decode(base64Url.normalize(stem)));
    } catch (_) {
      return null;
    }
  }
}
