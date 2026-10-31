import 'dart:convert';
import 'dart:io';

import 'package:flutter_lab/data/ace_client.dart';
import 'package:flutter_lab/data/records.dart';
import 'package:flutter_lab/data/secret_store.dart';
import 'package:flutter_lab/domain/ace.dart';
import 'package:flutter_lab/domain/cabinet_feed.dart';
import 'package:flutter_lab/domain/campus.dart';
import 'package:flutter_lab/domain/campus_route.dart';
import 'package:flutter_lab/domain/campus_schema.dart';
import 'package:flutter_lab/domain/campus_sites.dart';
import 'package:flutter_lab/domain/grades.dart';
import 'package:flutter_lab/domain/schedule.dart';
import 'package:flutter_lab/domain/time_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

ZachRow row({String dis = 'Предмет', String controlForm = 'Экзамен', String mark = '', int? markNumber, int sem = 1, num? hours, num? zet, String? teacherName, String? dateExam, String? year}) =>
    ZachRow(dis: dis, controlForm: controlForm, mark: mark, markNumber: markNumber, sem: sem, course: 1, hours: hours, zet: zet, teacherName: teacherName, dateExam: dateExam, year: year);

String js(num v) => v == v.truncate() ? '${v.toInt()}' : '$v';

String endsJson(RouteEnds e) => jsonEncode({if (e.from != null) 'from': e.from, if (e.to != null) 'to': e.to});

void main() {
  final fx = (jsonDecode(File('test/fixtures/stage3.json').readAsStringSync()) as Map).cast<String, String>();
  void same(String key, String got) => expect(got, fx[key], reason: key);

  final rows = [
    row(dis: 'Математика', markNumber: 5, mark: 'отлично', sem: 1, hours: 144, zet: 4, dateExam: '2026-01-15T00:00:00', teacherName: 'Иванов И.И.', year: '2025-2026'),
    row(dis: 'Физика', markNumber: 4, mark: 'хорошо', sem: 1, hours: 108),
    row(dis: 'История', markNumber: 3, mark: 'удовлетворительно', sem: 2, zet: 3.5),
    row(dis: 'Химия', markNumber: 2, mark: 'неудовлетворительно', sem: 2),
    row(dis: 'Философия', controlForm: 'Зачёт', markNumber: 7, mark: 'зачтено', sem: 1, dateExam: '2026-01-10'),
    row(dis: 'Физкультура', controlForm: 'Зачёт', mark: 'не зачтено', sem: 2),
    row(dis: 'Практика', controlForm: 'зачет с оценкой', sem: 3),
    row(dis: 'Программирование на Java', markNumber: 5, sem: 3, dateExam: 'не дата'),
    row(dis: 'Программирование на java', markNumber: 4, sem: 4),
    row(dis: 'Английский язык', controlForm: 'Диф. зачёт', mark: 'Зачет', sem: 4, hours: 72),
  ];
  final book = ZachBook(studentName: 'Иванов', avgPoint: 4.3333333, currentSem: 4, rows: rows, share: const [], loadedAt: 0);

  test('оценки: плашка, зачёты, сведения, поиск по предмету, статистика семестров', () {
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final b = gradeBadge(r);
      same('badge#$i', [b.tone.name, b.value, b.word, hasGrade(r), isCreditRow(r), examDate(r.dateExam), examDay(r.dateExam), gradeMeta(r), gradeMeta(r, showSem: true)].join('|'));
    }
    for (final s in ['Математика', 'программирование', 'JAVA', 'Физика и химия', '', 'нет такой']) {
      same('subject#$s', rowsForSubject(book, s).map((r) => '${r.dis}:${r.sem}').join(','));
    }
    for (final n in ['Программирование на Java', 'математика', 'нет']) {
      for (final sem in [null, 3]) {
        same('discipline#$n#${sem ?? 'undefined'}', rowsOfDiscipline(book, n, sem).map((r) => '${r.dis}:${r.sem}').join(','));
      }
      same('discipline#$n#null', rowsOfDiscipline(book, n, null).map((r) => '${r.dis}:${r.sem}').join(','));
    }
    same('stats', semesterStats(book).map((s) => '${s.sem}:${s.avg?.toStringAsFixed(6) ?? ''}:${s.marks}:${s.credits}').join(';'));
    expect(semesterStats(null), isEmpty);
    for (final v in [null, 4, 4.75, 4.333333, 3.995, 5, 0]) {
      for (final d in [1, 2]) {
        same('comma#$v#$d', decimalComma(v, d));
      }
    }
  });

  test('лента кабинета: пропуски, фильтры, сводка', () {
    final items = [
      const AceFeedItem(id: '1', category: 'Пропуски', kind: 'absence', text: 'Вам выставлен пропуск по дисциплине "Физика" за 07.09.2026', date: '07.09.2026', time: null, isNew: true),
      const AceFeedItem(id: '2', category: 'Оценки', kind: 'absence', text: 'Вам выставлен пропуск по дисциплине «Химия»', date: '08.09.2026', time: null, isNew: false),
      const AceFeedItem(id: '3', category: 'Другое', kind: 'absence', text: 'Пропуск непонятный', date: null, time: null, isNew: false),
      const AceFeedItem(id: '4', category: 'Оценки', kind: 'grade', text: 'Оценка 5', date: null, time: null, isNew: true),
      const AceFeedItem(id: '5', category: 'Перемещения', kind: 'move', text: 'Приказ', date: null, time: null, isNew: false),
    ];
    for (var i = 0; i < items.length; i++) {
      final a = absenceOf(items[i]);
      same('absence#$i', a == null ? 'null' : '${a.dis}|${a.date}');
    }
    for (final f in feedFilters) {
      same('feed#$f', filterFeed(items, f).map((x) => x.id).join(','));
    }
    for (final (a, u) in [(0, 0), (1, 0), (2, 1), (5, 3), (11, 11), (21, 22)]) {
      same('summary#$a#$u', feedSummary(a, u));
    }
  });

  test('маршрут по расписанию, итог, ссылка, подпись, поиск корпуса', () {
    final pi25 = loadSeedPackages().firstWhere((p) => p.code == 'ПИ-25а');
    final fixed = DateTime.utc(2026, 10, 25, 12);
    for (final sub in [0, 1, 2]) {
      for (final d in ['2026-10-21', '2026-10-23', '2026-10-24', '2026-10-26', '2026-10-30']) {
        final date = parseYmd(d)!;
        final items = lessonsForDate(pi25, date, sub, fixed);
        final tomorrow = nextStudyDay(pi25, date, sub, fixed)?.items ?? const <DayLesson>[];
        for (final minute in [0, 480, 575, 600, 800, 1000, 1300]) {
          final from = routeFromLessons(items, minute);
          final next = nextLessonWithBuilding(items, minute);
          same('route#$sub#$d#$minute', '${from.from ?? ''}>${from.to ?? ''}|${next != null ? '${next.building}:${next.item.key}' : ''}|${endsJson(routeFromLessons(tomorrow, 0))}');
        }
      }
    }
    final ids = <String?>[...campusBuildings.map((b) => b.id), 'x', null];
    for (final a in ids) {
      for (final b in ids) {
        final k = '${a ?? 'undefined'}>${b ?? 'undefined'}';
        final ends = RouteEnds(from: a, to: b);
        final s = routeSummary(ends);
        same(
          'summaryRoute#$k',
          switch (s) { null => 'null', RouteSame() => '{"kind":"same"}', RouteUnknown() => '{"kind":"unknown"}', RouteWalk() => '{"kind":"walk","minutes":${s.minutes},"meters":${s.meters}}' },
        );
        same('link#$k', '${routeLink(ends)}');
        same('caption#$k', routeCaption(ends));
        same('resolve#$k', endsJson(resolveRoute(ends, const RouteEnds(from: '4', to: '1'))));
        same('resolveAuto#$k', endsJson(resolveRoute(ends, RouteEnds(from: '2', to: b))));
      }
    }
    for (final q in ['4.418', 'корпус 8', '8', 'баз', 'артёма', 'артема', 'кобозева', '11.244б', '', '  ', 'нет', 'корпус', 'главный', '1', '25', 'ПРОСП']) {
      same('search#$q', searchBuildings(q).map((h) => '${h.building.id}:${h.room ?? ''}:${h.kind}').join(','));
    }
  });

  test('схема кампуса: попадание по контуру и метке, пересчёт точки, ограничение сдвига', () {
    var checked = 0;
    for (final e in campusSites.entries) {
      final site = e.value;
      for (var x = 0; x <= site.width; x += 50) {
        for (var y = 0; y <= site.height; y += 50) {
          same('hit#${e.key}#$x#$y', '${hitBuilding(site, x.toDouble(), y.toDouble())}');
          checked++;
        }
      }
      final b = site.buildings.first;
      same('hitReach#${e.key}', [30, 60].map((r) => hitBuilding(site, b.centerX + 40, b.centerY, reach: r.toDouble())).join(','));
      for (final (width, height) in [(400.0, 352.0), (1000.0, 880.0)]) {
        for (final (scale, tx, ty) in [(1.0, 0.0, 0.0), (2.5, -30.0, 12.0), (4.0, 100.0, -80.0)]) {
          final p = toViewBox(123, 77, viewOf(scale, tx, ty, width, height), site);
          same('viewBox#${e.key}#${js(width)}#${js(scale)}', '${p.$1.toStringAsFixed(6)},${p.$2.toStringAsFixed(6)}');
        }
      }
    }
    expect(checked, greaterThan(400));
    for (final (t, s, size) in [(100.0, 1.0, 400.0), (100.0, 2.0, 400.0), (-300.0, 2.5, 400.0), (5.0, 4.0, 1000.0), (-2000.0, 4.0, 1000.0)]) {
      same('pan#${js(t)}#${js(s)}#${js(size)}', js(clampPan(t, s, size)));
    }
  });

  group('разбор ответов ACE совпадает с клиентом из packages/api-client', () {
    late HttpServer server;
    late Map<String, dynamic> raw;
    late AceClient client;

    setUp(() async {
      raw = jsonDecode(fx['rawJson']!) as Map<String, dynamic>;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final key = request.uri.hasQuery ? '${request.uri.path}?${request.uri.query}' : request.uri.path;
        request.response.headers.contentType = ContentType.json;
        Future<void> respond(int status, Object json) async {
          request.response.statusCode = status;
          request.response.write(jsonEncode(json));
          await request.response.close();
        }

        if (key == '/api/tokenauth' && request.method == 'POST') {
          final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map<String, dynamic>;
          switch (body['userName']) {
            case 'ok':
              return respond(200, {'state': 1, 'msg': '', 'data': {'accessToken': 'tok-1'}});
            case 'twofa':
              return respond(200, {'state': 0, 'msg': 'Введи код из письма', 'data': {'require2FA': true, 'email': 'a@b.ru'}});
            case 'twofa-silent':
              return respond(200, {'state': 0, 'msg': '', 'data': {'require2FA': true}});
            case 'bad':
              return respond(200, {'state': 0, 'msg': 'Неверный пароль', 'data': {}});
            case 'err':
              return respond(200, {'state': 0, 'msg': 'Учётная запись заблокирована', 'data': {}});
            case 'empty':
              return respond(200, {'state': 0, 'msg': '', 'data': {}});
            case 'unauth':
              return respond(401, {});
            case 'busy':
              return respond(429, {});
            default:
              return respond(500, {});
          }
        }
        if (key == '/api/auth/Captcha') return respond(200, {'image': 'QUJD', 'key': 'cap-1'});
        return respond(200, raw[key] ?? {'state': 0, 'msg': 'нет', 'data': null});
      });
      client = AceClient(baseUrl: 'http://127.0.0.1:${server.port}', secrets: MemorySecretStore(), records: MemoryRecords(), fingerprint: () => 'fp');
    });

    tearDown(() => server.close(force: true));

    String strip(Object o) => jsonEncode(jsonDecode(jsonEncode(o))..remove('loadedAt'));

    test('вход: все исходы совпадают', () async {
      for (final user in ['ok', 'twofa', 'twofa-silent', 'bad', 'err', 'empty', 'unauth', 'busy']) {
        String got;
        try {
          final r = await client.login(userName: user, password: 'p');
          got = jsonEncode(switch (r) {
            LoginOk() => {'kind': 'ok', 'token': r.token},
            LoginCaptcha() => {'kind': 'captcha', 'image': 'data:image/png;base64,${r.imageBase64}', 'key': r.key, 'msg': r.message},
            LoginTwoFactor() => {'kind': '2fa', 'email': r.email, 'msg': r.message},
            LoginError() => {'kind': 'error', 'msg': r.message},
          });
        } on AceError catch (e) {
          got = 'ERR:${e.message}';
        }
        final want = fx['login#$user']!;
        if (want.startsWith('ERR:')) {
          expect(got, want, reason: user);
        } else {
          expect(jsonDecode(got), jsonDecode(want), reason: user);
        }
      }
      await expectLater(client.login(userName: 'zzz', password: 'p'), throwsA(isA<AceError>().having((e) => e.message, 'message', 'Сервис недоступен — попробуйте позже')));
    });

    test('студенческий, лента и зачётка', () async {
      expect(jsonDecode(strip((await client.student('t')).toJson())), jsonDecode(fx['student']!));
      expect(jsonDecode(strip((await client.feed('t')).toJson())), jsonDecode(fx['feed']!));
      expect(jsonDecode(strip((await client.zachBook('t')).toJson())), jsonDecode(fx['book']!));
    });

    test('токен хранится только в защищённом хранилище, пароль нигде', () async {
      final secrets = MemorySecretStore();
      final records = MemoryRecords();
      final c = AceClient(baseUrl: 'http://127.0.0.1:${server.port}', secrets: secrets, records: records);
      final r = await c.login(userName: 'ok', password: 'очень-секретный-пароль');
      expect(r, isA<LoginOk>());
      expect(await c.token(), 'tok-1');
      expect(secrets.values.values, ['tok-1']);
      expect(records.data.values.join(), isNot(contains('tok-1')));
      expect(records.data.values.join(), isNot(contains('очень-секретный-пароль')));
      expect(secrets.values.values.join(), isNot(contains('очень-секретный-пароль')));
      await c.student('tok-1');
      await c.logout();
      expect(await c.token(), isNull);
      expect(await c.cachedStudent(), isNull);
      expect(records.data.keys.where((k) => k.startsWith('personal:')), isEmpty);
    });
  });
}
