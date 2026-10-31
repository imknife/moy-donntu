import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show SizedBox;
import 'package:flutter/services.dart';
import 'package:flutter_lab/app.dart';
import 'package:flutter_lab/data/ace_client.dart';
import 'package:flutter_lab/data/app_controller.dart';
import 'package:flutter_lab/data/material_files.dart';
import 'package:flutter_lab/data/native_bridge.dart';
import 'package:flutter_lab/data/records.dart';
import 'package:flutter_lab/data/secret_store.dart';
import 'package:flutter_lab/data/loader.dart';
import 'package:flutter_lab/data/schedule_model.dart';
import 'package:flutter_lab/data/store.dart';
import 'package:flutter_lab/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final friday1000 = DateTime.utc(2026, 10, 23, 7);

SeedBytes readSeed() => SeedBytes(
      Uint8List.fromList(File('assets/seed/seed.json').readAsBytesSync()),
      Uint8List.fromList(File('assets/seed/teachers.json').readAsBytesSync()),
    );

Future<void> loadFonts() async {
  const weights = ['400Regular', '500Medium', '600SemiBold', '700Bold'];
  final onest = FontLoader('Onest');
  for (final w in weights) {
    onest.addFont(Future.value(ByteData.sublistView(File('assets/fonts/Onest_$w.ttf').readAsBytesSync())));
  }
  await onest.load();
  final lucide = FontLoader('LucideSubset')..addFont(rootBundle.load('assets/fonts/LucideSubset.ttf'));
  await lucide.load();
}

GroupPackage withOverrides(GroupPackage pkg, List<Override> overrides) => GroupPackage(
      code: pkg.code,
      semesterStart: pkg.semesterStart,
      bells: pkg.bells,
      calendar: pkg.calendar,
      lessons: pkg.lessons,
      overrides: overrides,
      lastChange: pkg.lastChange,
      contentHash: pkg.contentHash,
      updatedAt: pkg.updatedAt,
      version: pkg.version,
    );

class FakeFiles implements MaterialFiles {
  final List<String> opened = [];
  final List<String> deleted = [];
  ({String name, String path, int? size})? next = (name: 'Конспект.pdf', path: '/tmp/Конспект.pdf', size: 2048);

  @override
  Future<({String name, String path, int? size})?> pick() async => next;

  @override
  Future<void> open(String path, String name) async => opened.add(name);

  @override
  Future<void> delete(String path) async => deleted.add(path);
}

Future<AppController> makeController({
  String? group,
  int subgroup = 0,
  Map<String, Object> stored = const {},
  DateTime? now,
  List<Override>? overrides,
  MemorySecretStore? secrets,
  MemoryRecords? records,
  MaterialFiles? files,
  AceClient? ace,
  NativeBridge? native,
}) async {
  SharedPreferences.setMockInitialValues({
    if (group != null) 'selection': jsonEncode({'group': group, 'subgroup': subgroup}),
    ...stored,
  });
  final store = AppStore.fromPreferences(await SharedPreferences.getInstance());
  final secretStore = secrets ?? MemorySecretStore();
  final recordStore = records ?? MemoryRecords();
  final bytes = readSeed();
  final startup = parseStartupSync(bytes, store.selection.value.group);
  var loaded = startup.loaded;
  if (loaded != null && overrides != null) loaded = LoadedGroup(pkg: withOverrides(loaded.pkg, overrides), names: loaded.names);
  return AppController(
    store: store,
    bytes: bytes,
    groups: startup.groups,
    loaded: loaded,
    clock: MskClock(now: () => now ?? friday1000),
    secrets: secretStore,
    records: recordStore,
    files: files ?? FakeFiles(),
    native: native,
    ace: ace ?? AceClient(baseUrl: 'http://127.0.0.1:1', secrets: secretStore, records: recordStore),
  );
}

Future<void> pumpApp(WidgetTester tester, AppController controller) async {
  await tester.binding.setSurfaceSize(const Size(420, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(App(controller: controller));
  await tester.pump();
}

Future<void> settleIsolates(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
  await tester.pumpAndSettle();
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

Future<void> pumpUntilFound(WidgetTester tester, Finder finder, {int tries = 30}) async {
  for (var i = 0; i < tries && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

List<GroupPackage> loadSeedPackages() {
  final root = jsonDecode(File('assets/seed/seed.json').readAsStringSync()) as Map<String, dynamic>;
  final entries = root['entries'] as Map<String, dynamic>;
  final groups = (entries['public:/groups'] as Map<String, dynamic>)['groups'] as List;
  return [
    for (final g in groups)
      if (entries['public:/groups/${Uri.encodeComponent(g['code'] as String)}/package'] != null)
        GroupPackage.fromJson(entries['public:/groups/${Uri.encodeComponent(g['code'] as String)}/package'] as Map<String, dynamic>),
  ];
}

Future<void> settleBounded(WidgetTester tester) => tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
