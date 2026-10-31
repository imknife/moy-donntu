import 'dart:convert';
import 'dart:io';

import 'package:flutter_lab/domain/brand.dart';
import 'package:flutter_lab/domain/campus.dart';
import 'package:flutter_lab/domain/directory.dart';
import 'package:flutter_lab/domain/models.dart';
import 'package:flutter_lab/domain/notes.dart';
import 'package:flutter_lab/domain/now_card.dart';
import 'package:flutter_lab/domain/room_display.dart';
import 'package:flutter_lab/domain/schedule.dart';
import 'package:flutter_lab/domain/study_tools.dart';
import 'package:flutter_lab/domain/time_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

String shared(List<SharedLesson> rows) => rows.map((l) => [l.day, l.num, l.week, l.subgroup, l.subject, l.kind, l.rooms.join('/'), l.teachers.join('/'), l.groups.join('/')].join('|')).join(';');

String free(FreeRooms r) => '${r.free.map((x) => [x.label, x.building, x.floor ?? '', x.freeUntil ?? ''].join('|')).join(';')}#${r.basedOnGroups}';

String lessonSig(DayLesson i) => [i.key, i.num, i.lesson.subgroup, i.lesson.kind, i.override ?? '', i.overrideNote ?? '', i.change ?? '', i.bell.start, i.bell.end].join('|');

String busySig(RoomDay r) => [
      r.known,
      r.room?.label ?? '',
      r.basedOnGroups,
      r.from,
      r.to,
      r.busy.map((b) => '${b.from}-${b.to}').join(','),
      r.lessons.map((l) => '${l.group}:${lessonSig(l.item)}').join(';'),
    ].join('#');

String hits(List<TeacherHit> h) => h.map((t) => [t.name, t.rank, t.lessons].join('|')).join(';');

String js(num v) => v == v.truncate() ? '${v.toInt()}' : '$v';

void main() {
  final fx = (jsonDecode(File('test/fixtures/stage2.json').readAsStringSync()) as Map).cast<String, String>();
  final packages = loadSeedPackages();
  final raw = jsonDecode(File('test/fixtures/packages.json').readAsStringSync()) as Map<String, dynamic>;
  final synthetic = GroupPackage.fromJson(raw['СИНТ'] as Map<String, dynamic>);
  final pi25 = packages.firstWhere((p) => p.code == 'ПИ-25а');
  final ii23 = packages.firstWhere((p) => p.code == 'ИИ-23');
  final fixed = DateTime.utc(2026, 10, 25, 12);

  void same(String key, String got) => expect(got, fx[key], reason: key);

  test('справочник: преподаватели, аудитории, свободные аудитории', () {
    expect('${packages.length}', fx['packages']);
    same('hitsAll', hits(teacherHits(packages, '')));
    for (final q in ['ив', 'ко', 'а', ' ', 'щ']) {
      same('hits#$q', hits(teacherHits(packages, q)));
    }
    for (var i = 0; i < 6; i++) {
      final name = fx['teacher#$i']!;
      same('teacherSchedule#$i', shared(teacherSchedule(packages, name)));
    }
    same('roomList', free(roomList(packages)));
    for (var i = 0; i < 6; i++) {
      same('roomSchedule#$i', shared(roomSchedule(packages, fx['room#$i']!)));
    }
    var n = 0;
    for (final d in ['2026-10-26', '2026-10-27', '2026-10-31', '2026-11-04', '2026-12-25']) {
      for (final minute in [480, 575, 600, 700, 900, 1000, 1200]) {
        for (final b in [null, 4, 8]) {
          same('free#$d#$minute#${b ?? ''}', free(freeRoomsAt(packages, d, minute, building: b)));
          n++;
        }
      }
    }
    expect(n, 105);
  });

  test('аудитория на день и отображение', () {
    for (var i = 0; i < 6; i++) {
      for (final d in ['2026-10-26', '2026-10-28', '2026-10-31']) {
        final day = roomDay(packages, fx['room#$i']!, d);
        same('roomDay#$i#$d', busySig(day));
        final grouped = groupRoomLessons(day.lessons);
        same('grouped#$i#$d', grouped.map((g) => '${g.item.key}|${g.sources.map((s) => s.group).join(',')}|${g.conflict}').join(';'));
        final slots = roomSlots(packages[0].bells!.weekday, grouped);
        same('slots#$i#$d', slots.map((s) => '${s.bell.num}:${s.rows.map((x) => x.item.key).join(',')}').join(';'));
        same(
          'agenda#$i#$d',
          roomAgenda(slots).map((a) => switch (a) { AgendaBusy() => 'busy:${a.bell.num}:${a.row.item.key}', AgendaFree() => 'free:${a.from}-${a.to}:${a.toEnd}' }).join(';'),
        );
        for (final minute in [400, 480, 600, 800, 1000, 1300]) {
          final st = roomStatus(day.busy, minute);
          same('status#$i#$d#$minute', '${st.busy}|${st.until ?? ''}');
        }
        same('ticks#$i#$d', roomHourTicks(day.from, day.to).join(','));
      }
    }
    same('unknownRoom', busySig(roomDay(packages, 'нет такой', '2026-10-26')));
    for (final (r, f) in [('408', 4), ('003а', 0), ('4.418', 4), ('705', 7), ('', 1), ('12', 3), ('11.243', null)]) {
      same('cabinet#$r#$f', '${cabinetOf(r, f)}');
    }
    for (final day in [1, 5, 6, 7]) {
      for (var m = 0; m <= 1300; m += 25) {
        same('snap#$day#$m', '${snapToBell(m, day)}');
      }
    }
  });

  test('карточка «Сейчас», состояние дня, окна и нагрузка недели', () {
    var checked = 0;
    for (final (name, pkg) in [('pi', pi25), ('ii', ii23), ('syn', synthetic)]) {
      for (final sub in [0, 1, 2]) {
        for (final d in ['2026-10-21', '2026-10-23', '2026-10-24', '2026-10-26', '2026-10-30', '2026-11-04']) {
          final date = parseYmd(d)!;
          final items = lessonsForDate(pkg, date, sub, fixed);
          same('gaps#$name#$sub#$d', gapsOf(items).map((g) => g == null ? '-' : '${g.kind}:${g.from}-${g.to}:${g.minutes}:${g.walkTo ?? ''}').join(','));
          String? dayOff;
          for (final h in pkg.calendar?.holidays ?? const <Holiday>[]) {
            if (h.date == d) dayOff = h.name;
          }
          for (var minute = 0; minute <= 1300; minute += 15) {
            final st = nowState(items, minute.toDouble());
            final sig = switch (st) {
              NowBefore() => ['before', st.next.key, '', st.minutes, '', ''],
              NowLive() => ['live', st.next?.key ?? '', st.current.key, st.left, st.progress.toStringAsFixed(6), ''],
              NowGap() => [st.window ? 'window' : 'break', st.next.key, '', st.minutes, '', '${st.gap.kind}:${st.gap.walkTo ?? ''}'],
              NowDone() => ['done', '', '', st.endedAt, '', ''],
              NowEmpty() => ['empty', '', '', '', '', ''],
            };
            same('now#$name#$sub#$d#${js(minute)}', sig.join('|'));
            for (final today in [true, false]) {
              final c = nowCardModel(items: items, minute: minute.toDouble(), today: today, dayOffName: dayOff);
              final kind = c.kind == NowCardKind.pause ? 'break' : c.kind.name;
              same(
                'card#$name#$sub#$d#${js(minute)}#$today',
                [kind, c.title, c.lesson?.key ?? '', c.countdown ?? '', c.countdownLabel ?? '', c.progress?.toStringAsFixed(6) ?? '', c.walkTo ?? '', c.nextLesson?.key ?? ''].join('|'),
              );
              checked++;
            }
          }
        }
        same('weekCounts#$name#$sub', ['2026-10-19', '2026-10-26', '2026-11-02'].map((d) => weekCounts(pkg, parseYmd(d)!, sub).join(',')).join(';'));
      }
    }
    expect(checked, greaterThan(5000));
    for (final n in [0, 1, 5, 59, 60, 61, 125, 7.2]) {
      same('countdown#${js(n)}', countdownParts(n).map((p) => '${p.value}${p.unit}').join(' '));
    }
  });

  test('учёбные инструменты, приветствие, даты', () {
    for (var n = 0; n <= 35; n++) {
      same('pluralDays#$n', pluralDays(n));
    }
    for (var h = 0; h < 24; h++) {
      same('greeting#$h', greeting(h));
    }
    for (final n in ['', 'Иван Иванов', '  Пётр  Петров Петрович ', 'Один']) {
      same('first#$n', firstName(n));
      same('display#$n', displayFromFullName(n));
    }
    for (final d in ['2026-10-23', '2026-02-01', 'нет']) {
      same('human#$d', humanDate(d));
    }
    for (final d in ['2026-08-20', '2026-09-01', '2026-10-25', '2026-12-23', '2026-12-24', '2026-12-31', '2027-01-11', '2027-01-31', '2027-02-05', '2027-02-08', '2027-06-10', '2027-07-06', '2027-07-07', '2027-09-02']) {
      final dt = parseYmd(d)!;
      final p = currentPeriod(pi25.calendar, dt);
      same('period#$d', p == null ? '' : '${p.kind}:${p.from}:${p.to}');
      final s = sessionStatus(pi25.calendar, dt);
      final sig = switch (s) {
        SessionNone() => ['none', '', '', ''],
        SessionAhead() => ['ahead', s.days, '', s.period.from],
        SessionRunning() => ['running', '', s.daysLeft, s.period.from],
        SessionOver() => ['over', '', '', ''],
      };
      same('session#$d', sig.join('|'));
      expect(currentPeriod(null, dt), isNull);
      expect(sessionStatus(null, dt), isA<SessionNone>());
    }
    List<TimeSpan> busy(List<List<int>> a) => [for (final x in a) TimeSpan(x[0], x[1])];
    final bells = pi25.bells!.weekday;
    final cases = <(List<Bell>, List<TimeSpan>, List<TimeSpan>)>[
      (bells, busy([[480, 575]]), busy([[600, 700]])),
      (bells, busy([]), busy([])),
      (bells, busy([[400, 1300]]), busy([])),
      (bells, busy([[480, 575], [595, 690]]), busy([[690, 805], [1000, 1100]])),
      (const [], busy([[1, 2]]), busy([])),
    ];
    for (var i = 0; i < cases.length; i++) {
      same('cw#$i', commonWindows(cases[i].$1, cases[i].$2, cases[i].$3).map((w) => '${w.from}-${w.to}').join(','));
      same('cw30#$i', commonWindows(cases[i].$1, cases[i].$2, cases[i].$3, min: 90).map((w) => '${w.from}-${w.to}').join(','));
    }
    for (final m in [0, 479, 480, 574, 575, 576, 594, 595, 1250, 1300]) {
      final st = bellState(bells, m);
      same('bellState#$m', st == null ? 'null' : '{"kind":"${st.kind}","num":${st.num}}');
    }
  });

  test('список заметок: строки, подписи дат, фильтры, превью', () {
    final notes = [for (final n in jsonDecode(jsonEncode(_notes)) as List) Note.fromJson(n as Map<String, dynamic>)];
    for (final now in ['2026-10-25T12:00:00.000Z', '2026-10-26T00:30:00.000Z', '2026-10-28T09:00:00.000Z', '2026-11-30T09:00:00.000Z']) {
      final msk = toMsk(DateTime.parse(now));
      same(
        'rows#$now',
        buildNoteRows(notes, msk).map((r) => switch (r) { NoteHeaderRow() => 'H:${r.title}', NoteItemRow() => 'N:${r.note.id}' }).join(','),
      );
      same('labels#$now', notes.map((x) => noteDateLabel(x.updatedAt, msk)).join('|'));
    }
    for (final f in noteFilters) {
      for (final q in ['', 'лаб', 'ПЕРВ', 'нет такого']) {
        same('filter#$f#$q', filterNotes(notes, f, q).map((x) => x.id).join(','));
      }
    }
    same('top', '${topNotes(notes, 3).map((x) => x.id).join(',')}/${topNotes(notes, 10).map((x) => x.id).join(',')}');
    same('tags', '${notes.map((x) => noteKindTag(x.kind)).join(',')}${noteKindTag(null)}${noteKindTag('other')}');
    same('previews', notes.map(notePreview).join('|'));
  });

  test('кампус: ходьба, маршруты по сети проходов, ссылки, разбор запроса', () {
    for (final a in campusBuildings) {
      for (final b in campusBuildings) {
        final k = '${a.id}>${b.id}';
        final w = campusWalk(a.id, b.id);
        same('walk#$k', w == null ? '' : '${w.minutes}:${w.meters}');
        same('yroute#$k', '${yandexRouteUrl(a, b)}');
        final r = campusPathRoute(a.id, b.id);
        same('path#$k', r == null ? '' : '${r.nodes.join(',')}|${r.meters}|${r.coordinates.length}|${_coord(r.coordinates.first)}|${_coord(r.coordinates.last)}');
        final pw = campusPathWalk(a.id, b.id);
        same('pathWalk#$k', pw == null ? '' : '${pw.minutes}:${pw.meters}');
      }
      same('ymaps#${a.id}', '${yandexMapsUrl(a)}');
      same('reach#${a.id}', reachableBuildings(a.id).join(','));
    }
    for (final q in ['4.418', '11.244б', 'корпус 8', '  Корпус  5 ', '8. 705', '4.41', 'abc', '12', '004.418', '4.418А']) {
      final p = parseRoomQuery(q);
      same('parse#$q', p == null ? 'null' : jsonEncode({'building': p.building, if (p.room != null) 'room': p.room, if (p.floor != null) 'floor': p.floor}));
    }
    same('geo', geoDistance((37.8, 48.0), (37.81, 48.01)).toStringAsFixed(6));
  });

  test('имена преподавателей и бренд', () {
    for (final key in fx.keys.where((k) => k.startsWith('short#'))) {
      final n = key.substring(6);
      same(key, '${shortTeacherName(n)}');
    }
    for (final key in fx.keys.where((k) => k.startsWith('shortFull#'))) {
      same(key, '${shortTeacherName(key.substring(10))}');
    }
    same('fullNames', jsonEncode(teacherFullNames(['Щедрин Сергей Владимирович', 'Щедрин Степан Васильевич', 'Иванов Иван', 'Один'])));
    for (final id in ['pairs', 'donntu', 'x', null]) {
      final b = brandFor(id);
      same('brand#$id', jsonEncode({'id': b.id, 'title': b.title, 'tagline': b.tagline, 'disclaimer': b.disclaimer}));
    }
    for (final l in pi25.lessons.take(10)) {
      same('building#${l.day}${l.num}${l.subject}', '${buildingOf(l)}');
    }
  });
}

String _coord(LngLat p) => '${js(p.$1)},${js(p.$2)}';

const _notes = [
  {'id': 'a', 'title': 'Лаба', 'text': '☐ сдать\n☑ отчёт', 'lessonKey': 'k1', 'lessonDate': '2026-10-23', 'subject': 'Алгоритмы', 'kind': 'lab', 'updatedAt': '2026-10-25T08:00:00.000Z'},
  {'id': 'b', 'title': '', 'text': 'Первая строка\nвторая строка\n\nтретья', 'updatedAt': '2026-10-25T20:30:00.000Z', 'pinned': true},
  {'id': 'c', 'title': '', 'text': '', 'updatedAt': '2026-10-24T10:00:00.000Z', 'lessonKey': 'k2', 'kind': 'lecture'},
  {'id': 'd', 'title': 'Старая', 'text': 'x', 'updatedAt': '2025-12-31T21:30:00.000Z', 'kind': 'exam'},
  {'id': 'e', 'title': 'Эта неделя', 'text': 'y', 'updatedAt': '2026-10-21T09:00:00.000Z', 'kind': 'credit'},
  {'id': 'f', 'title': 'Плохая дата', 'text': 'z', 'updatedAt': 'не дата', 'kind': 'consultation'},
  {'id': 'g', 'title': 'Курсовая', 'text': '☐ ', 'updatedAt': '2026-10-25T08:00:00.000Z', 'kind': 'coursework', 'pinned': true},
];
