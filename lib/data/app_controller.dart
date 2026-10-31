import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../domain/brand.dart';
import '../domain/models.dart';
import 'ace_client.dart';
import 'api.dart';
import 'auth.dart';
import 'config.dart';
import 'loader.dart';
import 'material_files.dart';
import 'records.dart';
import 'resources.dart';
import 'native_bridge.dart';
import 'schedule_model.dart';
import 'secret_store.dart';
import 'seed_store.dart';
import 'specs.dart';
import 'store.dart';

Features withFeatureOverrides(Features served) {
  var f = served;
  for (final name in AppConfig.featureOverride) {
    f = switch (name) {
      'campus' => f.copyWith(campus: true),
      'knowledge' => f.copyWith(knowledge: true),
      'community' => f.copyWith(community: true),
      'friends' => f.copyWith(friends: true),
      _ => f,
    };
  }
  return f;
}

class AppController {
  AppController({
    required this.store,
    required this.bytes,
    required List<GroupInfo> groups,
    LoadedGroup? loaded,
    MskClock? clock,
    Records? records,
    ApiClient? api,
    SecretStore? secrets,
    AceClient? ace,
    MaterialFiles? files,
    NativeBridge? native,
  })  : native = native ?? const NoNativeBridge(),
        model = ValueNotifier(null),
        groups = ValueNotifier(groups),
        clock = clock ?? MskClock(),
        files = files ?? PlatformMaterialFiles() {
    final secretStore = secrets ?? MemorySecretStore();
    final recordStore = records ?? MemoryRecords();
    final apiClient = api ?? ApiClient(null);
    hub = ResourceHub(api: apiClient, records: recordStore, seed: SeedStore(bytes));
    auth = AuthService(
      ace: ace ?? AceClient(baseUrl: AppConfig.aceUrl, secrets: secretStore, records: recordStore),
      secrets: secretStore,
      records: recordStore,
      session: session,
    );
    names.addAll((jsonDecode(utf8.decode(bytes.teachers)) as Map<String, dynamic>).cast<String, String>());
    if (loaded != null) {
      _loaded = loaded;
      names.addAll(loaded.names);
      model.value = _makeModel();
    }
  }

  final AppStore store;
  final SeedBytes bytes;
  final ValueNotifier<List<GroupInfo>> groups;
  final ValueNotifier<ScheduleModel?> model;
  final MskClock clock;
  final MaterialFiles files;
  final NativeBridge native;
  late final ResourceHub hub;
  late final AuthService auth;
  final Map<String, String> names = {};
  final ValueNotifier<Features> features = ValueNotifier(withFeatureOverrides(const Features()));
  final ValueNotifier<BrandPreset> brand = ValueNotifier(brandFor(null));
  final ValueNotifier<int> tab = ValueNotifier(1);
  final ValueNotifier<DateTime?> selectedDay = ValueNotifier(null);
  final ValueNotifier<String?> session = ValueNotifier(null);
  LoadedGroup? _loaded;
  Timer? _timer;
  Resource<GroupPackage>? _watched;

  ScheduleModel _makeModel() => ScheduleModel(
        pkg: _loaded!.pkg,
        subgroup: store.selection.value.subgroup,
        names: names,
        nowInstant: clock.now(),
      );

  void startClock() {
    _timer?.cancel();
    final ms = 60000 - (DateTime.now().millisecondsSinceEpoch % 60000);
    _timer = Timer(Duration(milliseconds: ms + 50), () {
      clock.tick();
      startClock();
    });
  }

  void stopClock() => _timer?.cancel();

  Future<void> start() async {
    await _restoreFromCache();
    await auth.restore();
    if (session.value != null) {
      unawaited(auth.student.refresh());
      unawaited(auth.feed.refresh());
    }
    final featuresResource = hub.watch(featuresSpec());
    featuresResource.addListener(() {
      final served = featuresResource.value.data;
      if (served != null) features.value = withFeatureOverrides(served);
    });
    final brandResource = hub.watch(brandSpec());
    brandResource.addListener(() => brand.value = brandFor(brandResource.value.data));
    final namesResource = hub.watch(teacherNamesSpec());
    namesResource.addListener(() {
      final served = namesResource.value.data;
      if (served != null) names.addAll(served);
    });
    final groupsResource = hub.watch(groupsSpec());
    groupsResource.addListener(() {
      final list = groupsResource.value.data;
      if (list != null && list.isNotEmpty) groups.value = list;
    });
    bindPackage();
  }

  void warmDirectories() {
    hub.watch(teachersSpec());
    hub.watch(roomsSpec());
  }

  Future<void> _restoreFromCache() async {
    final code = store.selection.value.group;
    if (_loaded != null || code.isEmpty) return;
    final pkg = await hub.local(packageSpec(code));
    if (pkg == null || _loaded != null || store.selection.value.group != code) return;
    _loaded = LoadedGroup(pkg: pkg, names: names);
    model.value = _makeModel();
  }

  void bindPackage() {
    final code = store.selection.value.group;
    _watched?.removeListener(_onPackage);
    if (code.isEmpty) return;
    _watched = hub.watch(packageSpec(code))..addListener(_onPackage);
    unawaited(_watched!.refresh());
  }

  void _onPackage() {
    final pkg = _watched?.value.data;
    if (pkg == null || pkg.code != store.selection.value.group) return;
    final current = _loaded;
    if (current != null && pkg.code == current.pkg.code && pkg.contentHash == current.pkg.contentHash && pkg.updatedAt == current.pkg.updatedAt) return;
    _loaded = LoadedGroup(pkg: pkg, names: current?.names ?? names);
    model.value = _makeModel();
  }

  Future<void> chooseGroup(String code, {int? subgroup}) async {
    final loaded = await _loadLocal(code);
    _loaded = loaded;
    store.setGroup(code, subgroup ?? (code == store.selection.value.group ? store.selection.value.subgroup : 0));
    if (store.prefs.value.activeTeacher.isNotEmpty) store.setPrefs((p) => p.copyWith(activeTeacher: ''));
    model.value = _makeModel();
    bindPackage();
  }

  Future<LoadedGroup> _loadLocal(String code) async {
    final pkg = await hub.local(packageSpec(code));
    if (pkg != null) return LoadedGroup(pkg: pkg, names: _loaded?.names ?? names);
    try {
      return await parseGroup(bytes, code);
    } catch (_) {
      final fetched = await hub.fetch(packageSpec(code));
      return LoadedGroup(pkg: fetched, names: _loaded?.names ?? names);
    }
  }

  void chooseSubgroup(int subgroup) {
    if (_loaded == null || subgroup == store.selection.value.subgroup) return;
    store.setSubgroup(subgroup);
    model.value = _makeModel();
  }

  Future<void> refreshAll() async {
    await Future.wait([
      for (final r in [hub.watch(featuresSpec(), refresh: false), hub.watch(groupsSpec(), refresh: false)]) r.refresh(),
      if (_watched != null) _watched!.refresh(),
    ]);
  }

  void dispose() {
    _timer?.cancel();
    clock.dispose();
  }
}
