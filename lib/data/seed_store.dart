import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'loader.dart';

Map<String, String> _split(Uint8List seed) {
  final entries = (jsonDecode(utf8.decode(seed)) as Map<String, dynamic>)['entries'] as Map<String, dynamic>;
  return {for (final e in entries.entries) e.key: jsonEncode(e.value)};
}

class SeedStore {
  SeedStore(this.bytes);
  final SeedBytes bytes;
  Future<Map<String, String>>? _entries;

  Future<Map<String, String>> get entries => _entries ??= Isolate.run(() => _split(bytes.seed));

  Future<String?> raw(String key) async => (await entries)[key];

  Future<List<String>> packageTexts() async {
    final all = await entries;
    final groups = (jsonDecode(all['public:/groups']!) as Map<String, dynamic>)['groups'] as List;
    return [
      for (final g in groups)
        if (all['public:/groups/${Uri.encodeComponent(g['code'] as String)}/package'] != null) all['public:/groups/${Uri.encodeComponent(g['code'] as String)}/package']!,
    ];
  }
}
