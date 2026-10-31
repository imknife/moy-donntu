import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/models.dart';

class GroupInfo {
  const GroupInfo(this.code, this.course, this.faculty);
  final String code;
  final int? course;
  final String faculty;
}

class LoadedGroup {
  const LoadedGroup({required this.pkg, required this.names});
  final GroupPackage pkg;
  final Map<String, String> names;
}

class SeedBytes {
  const SeedBytes(this.seed, this.teachers);
  final Uint8List seed;
  final Uint8List teachers;
}

Future<SeedBytes> readSeedBytes() async {
  final seed = await rootBundle.load('assets/seed/seed.json');
  final teachers = await rootBundle.load('assets/seed/teachers.json');
  return SeedBytes(
    seed.buffer.asUint8List(seed.offsetInBytes, seed.lengthInBytes),
    teachers.buffer.asUint8List(teachers.offsetInBytes, teachers.lengthInBytes),
  );
}

typedef Startup = ({List<GroupInfo> groups, LoadedGroup? loaded});

Future<Startup> parseStartup(SeedBytes bytes, String? code) => Isolate.run(() => parseStartupSync(bytes, code));

Future<LoadedGroup> parseGroup(SeedBytes bytes, String code) => Isolate.run(() => parseGroupSync(bytes, code));

Map<String, dynamic> _entries(SeedBytes bytes) => (jsonDecode(utf8.decode(bytes.seed)) as Map<String, dynamic>)['entries'] as Map<String, dynamic>;

List<GroupInfo> _groups(Map<String, dynamic> entries) {
  final list = (entries['public:/groups'] as Map<String, dynamic>)['groups'] as List;
  return [
    for (final g in list)
      if ((g as Map<String, dynamic>)['hasSchedule'] == true) GroupInfo(g['code'] as String, g['course'] as int?, g['faculty'] as String? ?? ''),
  ];
}

LoadedGroup? _group(Map<String, dynamic> entries, SeedBytes bytes, String? code) {
  if (code == null || code.isEmpty) return null;
  final raw = entries['public:/groups/${Uri.encodeComponent(code)}/package'] as Map<String, dynamic>?;
  if (raw == null) return null;
  final names = (jsonDecode(utf8.decode(bytes.teachers)) as Map<String, dynamic>).cast<String, String>();
  return LoadedGroup(pkg: GroupPackage.fromJson(raw), names: names);
}

Startup parseStartupSync(SeedBytes bytes, String? code) {
  final entries = _entries(bytes);
  return (groups: _groups(entries), loaded: _group(entries, bytes, code));
}

LoadedGroup parseGroupSync(SeedBytes bytes, String code) {
  final loaded = _group(_entries(bytes), bytes, code);
  if (loaded == null) throw StateError('Нет пакета группы $code');
  return loaded;
}
