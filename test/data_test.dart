import 'dart:convert';
import 'dart:io';

import 'package:flutter_lab/data/api.dart';
import 'package:flutter_lab/data/app_controller.dart';
import 'package:flutter_lab/data/config.dart';
import 'package:flutter_lab/data/loader.dart';
import 'package:flutter_lab/data/records.dart';
import 'package:flutter_lab/data/resources.dart';
import 'package:flutter_lab/data/seed_store.dart';
import 'package:flutter_lab/data/specs.dart';
import 'package:flutter_lab/data/store.dart';
import 'package:flutter_lab/domain/directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support.dart';

class FakeServer {
  FakeServer(this.server) {
    server.listen((request) async {
      requests.add('${request.method} ${request.uri}');
      final auth = request.headers.value('authorization');
      if (auth != null) authHeaders.add(auth);
      final answer = routes[request.uri.path] ?? routes['${request.uri}'];
      request.response.headers.contentType = ContentType.json;
      if (answer == null) {
        request.response.statusCode = 404;
        request.response.write(jsonEncode({'message': 'нет такого'}));
      } else {
        request.response.statusCode = answer.$1;
        request.response.write(answer.$2);
      }
      await request.response.close();
    });
  }

  final HttpServer server;
  final Map<String, (int, String)> routes = {};
  final List<String> requests = [];
  final List<String> authHeaders = [];

  String get url => 'http://127.0.0.1:${server.port}/api';

  static Future<FakeServer> start() async => FakeServer(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  Future<void> stop() => server.close(force: true);
}

void main() {
  late Directory temp;

  setUp(() async => temp = await Directory.systemTemp.createTemp('flutter_lab_test'));

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  group('адрес API', () {
    test('в production принимает https и убирает завершающий слэш', () {
      expect(resolveApiUrl('https://api.example.ru/api/', production: true), 'https://api.example.ru/api');
    });

    test('в production отклоняет http для внешних адресов и локальной сети', () {
      expect(() => resolveApiUrl('http://api.example.ru/api', production: true), throwsFormatException);
      expect(() => resolveApiUrl('http://192.168.1.5:3100/api', production: true), throwsFormatException);
      expect(() => resolveApiUrl('ftp://api.example.ru', production: true), throwsFormatException);
    });

    test('http допустим для localhost, 127.0.0.1 и 10.0.2.2, а при разработке для любого адреса', () {
      for (final host in ['localhost', '127.0.0.1', '10.0.2.2']) {
        expect(resolveApiUrl('http://$host:3100/api', production: true), 'http://$host:3100/api');
      }
      expect(resolveApiUrl('http://192.168.1.5:3100/api', production: false), 'http://192.168.1.5:3100/api');
      expect(() => resolveApiUrl('http://localhost.evil.example/api', production: true), throwsFormatException);
    });

    test('пустой адрес отключает сеть, мусор даёт понятную ошибку', () {
      expect(resolveApiUrl('', production: true), isNull);
      expect(() => resolveApiUrl('не адрес', production: false), throwsFormatException);
    });
  });

  group('кеш на диске', () {
    test('запись, чтение, удаление и удаление по началу ключа', () async {
      final r = FileRecords(temp);
      expect(await r.get('public:/a'), isNull);
      await r.set('public:/a', '{"x":1}');
      await r.set('personal:abc:/b', 'секрет-кеш');
      await r.set('public:/Кириллица?x=1', 'ok');
      expect(await r.get('public:/a'), '{"x":1}');
      expect(await r.get('public:/Кириллица?x=1'), 'ok');
      await r.removePrefix('personal:');
      expect(await r.get('personal:abc:/b'), isNull);
      expect(await r.get('public:/a'), isNotNull);
      await r.remove('public:/a');
      expect(await r.get('public:/a'), isNull);
    });

    test('повреждённая запись не ломает чтение', () async {
      final r = FileRecords(temp);
      await r.set('public:/a', 'x');
      await File('${temp.path}${Platform.pathSeparator}мусор.rec').writeAsString('1');
      await r.removePrefix('public:');
      expect(await r.get('public:/a'), isNull);
    });
  });

  group('ресурсы', () {
    late FakeServer server;
    late SeedStore seed;

    setUp(() async {
      server = await FakeServer.start();
      seed = SeedStore(readSeed());
    });

    tearDown(() => server.stop());

    ResourceHub hub({Records? records, String? url}) => ResourceHub(api: ApiClient(url ?? server.url), records: records ?? MemoryRecords(), seed: seed);

    test('ответ сервера разбирается и пишется в кеш', () async {
      server.routes['/api/features'] = (200, jsonEncode({'knowledge': false, 'community': false, 'friends': true, 'campus': true}));
      final records = MemoryRecords();
      final f = await hub(records: records).fetch(featuresSpec());
      expect(f.campus, isTrue);
      expect(f.friends, isTrue);
      expect(await records.get('public:/features'), contains('"campus":true'));
    });

    test('справочник показывается из расписаний сразу, до ответа сервера', () async {
      server.routes['/api/rooms'] = (500, jsonEncode({'message': 'база'}));
      final h = hub();
      final r = h.watch(roomsSpec(), refresh: false);
      final seen = <ResourceState<FreeRooms>>[];
      r.addListener(() => seen.add(r.value));
      await r.refresh();
      expect(seen.any((s) => s.hasData && s.loading), isTrue);
    });

    test('пустой пакет группы не заменяет расписание, в котором есть пары', () async {
      final key = 'public:/groups/${Uri.encodeComponent('ПИ-25а')}/package';
      final raw = jsonDecode((await seed.raw(key))!) as Map<String, dynamic>;
      raw['lessons'] = [];
      server.routes['/api/groups/${Uri.encodeComponent('ПИ-25а')}/package'] = (200, jsonEncode(raw));
      final records = MemoryRecords();
      final r = hub(records: records).watch(packageSpec('ПИ-25а'), refresh: false);
      await r.refresh();
      expect(r.value.data!.lessons, isNotEmpty);
      expect(r.value.error, isNull);
      expect(await records.get(key), isNull);
    });

    test('при недоступном сервере берётся сохранённая копия', () async {
      final records = MemoryRecords();
      records.data['public:/features'] = jsonEncode({'campus': true});
      final h = hub(records: records, url: 'http://127.0.0.1:1/api');
      final r = h.watch(featuresSpec(), refresh: false);
      await r.refresh();
      expect(r.value.data!.campus, isTrue);
      expect(r.value.offline, isTrue);
    });

    test('групповой пакет без сети берётся из встроенного снимка', () async {
      final h = hub(url: 'http://127.0.0.1:1/api');
      final r = h.watch(packageSpec('ПИ-25а'), refresh: false);
      await r.refresh();
      expect(r.value.data!.code, 'ПИ-25а');
      expect(r.value.offline, isTrue);
    });

    test('справочник преподавателей без сервера считается из сохранённых расписаний', () async {
      final h = ResourceHub(api: ApiClient(null), records: MemoryRecords(), seed: seed);
      final teachers = await h.fetch(teachersSpec());
      expect(teachers.length, greaterThan(50));
      final free = await h.fetch(freeRoomsSpec('2026-10-26', 600));
      expect(free.free, isNotEmpty);
      final day = await h.fetch(roomDaySpec('8.705', '2026-10-26'));
      expect(day.known, isTrue);
    });

    test('ошибка сервера: ответ берётся из локальных расписаний', () async {
      server.routes['/api/rooms'] = (500, jsonEncode({'message': 'База недоступна'}));
      final h = ResourceHub(api: ApiClient(server.url), records: MemoryRecords(), seed: SeedStore(SeedBytes(readSeed().seed, readSeed().teachers)));
      final r = h.watch(roomsSpec(), refresh: false);
      await r.refresh();
      expect(r.value.data, isNotNull);
      expect(r.value.offline, isTrue);
    });

    test('запрос к серверу не несёт заголовка авторизации', () async {
      server.routes['/api/features'] = (200, jsonEncode({'knowledge': false, 'community': false, 'friends': true, 'campus': true}));
      await hub().fetch(featuresSpec());
      expect(server.requests, isNotEmpty);
      expect(server.authHeaders, isEmpty);
    });
  });

  group('контроллер обновляет расписание с сервера', () {
    test('новый пакет группы с другим хешем заменяет модель', () async {
      final server = await FakeServer.start();
      addTearDown(server.stop);
      final bytes = readSeed();
      final startup = parseStartupSync(bytes, 'ПИ-25а');
      final fresh = jsonDecode(jsonEncode(await _packageJson(bytes, 'ПИ-25а'))) as Map<String, dynamic>;
      fresh['contentHash'] = 'новый-хеш';
      (fresh['lessons'] as List).removeWhere((l) => l['day'] == 5);
      server.routes['/api/groups/${Uri.encodeComponent('ПИ-25а')}/package'] = (200, jsonEncode(fresh));
      SharedPreferences.setMockInitialValues({'selection': jsonEncode({'group': 'ПИ-25а', 'subgroup': 1})});
      final store = AppStore.fromPreferences(await SharedPreferences.getInstance());
      final c = AppController(store: store, bytes: bytes, groups: startup.groups, loaded: startup.loaded, api: ApiClient(server.url), records: FileRecords(temp));
      final before = c.model.value!;
      expect(before.items(DateTime.utc(2026, 10, 23)), isNotEmpty);
      c.bindPackage();
      for (var i = 0; i < 40 && identical(c.model.value, before); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(identical(c.model.value, before), isFalse);
      expect(c.model.value!.items(DateTime.utc(2026, 10, 23)), isEmpty);
      final cached = await FileRecords(temp).get('public:/groups/${Uri.encodeComponent('ПИ-25а')}/package');
      expect(cached, contains('новый-хеш'));
    });

    test('замена без смены хеша и версии (меняется только updatedAt) тоже доходит до модели', () async {
      final server = await FakeServer.start();
      addTearDown(server.stop);
      final bytes = readSeed();
      final startup = parseStartupSync(bytes, 'ПИ-25а');
      final fresh = jsonDecode(jsonEncode(await _packageJson(bytes, 'ПИ-25а'))) as Map<String, dynamic>;
      final hashBefore = startup.loaded!.pkg.contentHash;
      fresh['updatedAt'] = '2026-11-01T12:00:00.000Z';
      (fresh['overrides'] as List).add({'id': 9001, 'date': '2026-10-23', 'num': 1, 'subgroup': 0, 'action': 'cancel', 'lesson': null, 'note': null});
      server.routes['/api/groups/${Uri.encodeComponent('ПИ-25а')}/package'] = (200, jsonEncode(fresh));
      SharedPreferences.setMockInitialValues({'selection': jsonEncode({'group': 'ПИ-25а', 'subgroup': 1})});
      final store = AppStore.fromPreferences(await SharedPreferences.getInstance());
      final c = AppController(store: store, bytes: bytes, groups: startup.groups, loaded: startup.loaded, api: ApiClient(server.url), records: MemoryRecords());
      final before = c.model.value!;
      expect(before.pkg.overrides.any((o) => o.id == 9001), isFalse);
      c.bindPackage();
      for (var i = 0; i < 40 && identical(c.model.value, before); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(identical(c.model.value, before), isFalse);
      expect(c.model.value!.pkg.contentHash, hashBefore);
      expect(c.model.value!.pkg.overrides.any((o) => o.id == 9001), isTrue);
    });

    group('группа, которой нет во встроенных данных', () {
      const newCode = 'НОВ-26а';
      final path = '/groups/${Uri.encodeComponent(newCode)}/package';

      Future<String> newPackage() async {
        final json = jsonDecode(jsonEncode(await _packageJson(readSeed(), 'ПИ-25а'))) as Map<String, dynamic>;
        (json['group'] as Map<String, dynamic>)['code'] = newCode;
        json['contentHash'] = 'хеш-новой-группы';
        return jsonEncode(json);
      }

      Future<AppController> controllerFor({String? api, String selected = '', Records? records}) async {
        final bytes = readSeed();
        SharedPreferences.setMockInitialValues({
          if (selected.isNotEmpty) 'selection': jsonEncode({'group': selected, 'subgroup': 0}),
        });
        final store = AppStore.fromPreferences(await SharedPreferences.getInstance());
        final startup = parseStartupSync(bytes, selected);
        return AppController(store: store, bytes: bytes, groups: startup.groups, loaded: startup.loaded, api: ApiClient(api), records: records ?? MemoryRecords());
      }

      test('первый вход без группы: полные ФИО преподавателей уже загружены и остаются после выбора группы', () async {
        final c = await controllerFor();
        expect(c.model.value, isNull);
        expect(c.names['Боднар А.В.'], 'Боднар Алина Валериевна');
        await c.chooseGroup('ПИ-25а');
        expect(c.names['Боднар А.В.'], 'Боднар Алина Валериевна');
      });

      test('выбор: пакет запрашивается с сервера и кладётся в кеш', () async {
        final server = await FakeServer.start();
        addTearDown(server.stop);
        server.routes['/api$path'] = (200, await newPackage());
        final records = MemoryRecords();
        final c = await controllerFor(api: server.url, records: records);
        expect(c.model.value, isNull);
        await c.chooseGroup(newCode);
        expect(c.store.selection.value.group, newCode);
        expect(c.model.value, isNotNull);
        expect(c.model.value!.pkg.code, newCode);
        expect(await records.get('public:$path'), contains('хеш-новой-группы'));
      });

      test('выбор без сети: исключение, состояние не меняется', () async {
        final c = await controllerFor(api: 'http://127.0.0.1:1/api', selected: 'ПИ-25а');
        final before = c.model.value;
        await expectLater(c.chooseGroup(newCode), throwsA(anything));
        expect(c.store.selection.value.group, 'ПИ-25а');
        expect(identical(c.model.value, before), isTrue);
      });

      test('выбор без сети: закешированный пакет подходит', () async {
        final records = MemoryRecords();
        await records.set('public:$path', await newPackage());
        final c = await controllerFor(records: records);
        await c.chooseGroup(newCode);
        expect(c.model.value!.pkg.code, newCode);
      });

      test('запуск: выбранная группа вне встроенных данных собирается из кеша', () async {
        final records = MemoryRecords();
        await records.set('public:$path', await newPackage());
        final c = await controllerFor(selected: newCode, records: records);
        expect(c.model.value, isNull);
        await c.start();
        expect(c.model.value, isNotNull);
        expect(c.model.value!.pkg.code, newCode);
        c.stopClock();
      });

      test('пакет выбранной группы с сервера создаёт модель, когда её ещё нет', () async {
        final server = await FakeServer.start();
        addTearDown(server.stop);
        server.routes['/api$path'] = (200, await newPackage());
        final c = await controllerFor(api: server.url, selected: newCode);
        expect(c.model.value, isNull);
        c.bindPackage();
        for (var i = 0; i < 40 && c.model.value == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(c.model.value, isNotNull);
        expect(c.model.value!.pkg.code, newCode);
      });
    });

    test('особенности из конфигурации сборки включают разделы', () {
      expect(AppConfig.featureOverride, isEmpty);
    });

    test('модель без изменений хеша не пересоздаётся', () async {
      final bytes = readSeed();
      final startup = parseStartupSync(bytes, 'ПИ-25а');
      SharedPreferences.setMockInitialValues({'selection': jsonEncode({'group': 'ПИ-25а', 'subgroup': 1})});
      final store = AppStore.fromPreferences(await SharedPreferences.getInstance());
      final c = AppController(store: store, bytes: bytes, groups: startup.groups, loaded: startup.loaded, records: FileRecords(temp));
      final before = c.model.value;
      c.bindPackage();
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(identical(c.model.value, before), isTrue);
    });
  });

  test('сортировка справочника устойчива: результат не зависит от порядка пакетов', () {
    final a = teacherHits(loadSeedPackages(), '');
    final b = teacherHits(loadSeedPackages().reversed.toList(), '');
    expect(a.map((t) => t.name).toList(), b.map((t) => t.name).toList());
  });
}

Future<Map<String, dynamic>> _packageJson(SeedBytes bytes, String code) async {
  final root = jsonDecode(utf8.decode(bytes.seed)) as Map<String, dynamic>;
  return (root['entries'] as Map<String, dynamic>)['public:/groups/${Uri.encodeComponent(code)}/package'] as Map<String, dynamic>;
}
