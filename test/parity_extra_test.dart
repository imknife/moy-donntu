import 'dart:convert';
import 'dart:io';

import 'package:flutter_lab/domain/models.dart';
import 'package:flutter_lab/domain/notes.dart';
import 'package:flutter_lab/domain/schedule.dart';
import 'package:flutter_lab/domain/time_utils.dart';
import 'package:flutter_test/flutter_test.dart';

const nl = '\n';
final textSamples = ['', 'abc', '☐ a$nl☑ b${nl}plain', '☐ ', '☑ x$nl', '☐ один$nl☐ два$nl$nl☑ три', 'a${nl}b${nl}c'];

void main() {
  final fx = jsonDecode(File('test/fixtures/parity.json').readAsStringSync()) as Map<String, dynamic>;
  final raw = jsonDecode(File('test/fixtures/packages.json').readAsStringSync()) as Map<String, dynamic>;
  final pkgs = {for (final e in raw.entries) e.key: GroupPackage.fromJson(e.value as Map<String, dynamic>)};
  final start = parseYmd(fx['start'] as String)!;
  final days = fx['days'] as int;
  final cases = (fx['cases'] as Map).cast<String, String>();

  test('cancelledForDate совпадает с TS', () {
    var checked = 0;
    var nonEmpty = 0;
    for (final code in pkgs.keys) {
      for (final sub in [0, 1, 2]) {
        for (var i = 0; i < days; i++) {
          final d = addDays(start, i);
          final got = cancelledForDate(pkgs[code]!, d, sub).map((x) => [x.num, x.bell.start, x.subject, x.note ?? ''].join('|')).join(';');
          expect(got, cases['cancel#$code#$sub#${ymd(d)}'], reason: '$code $sub ${ymd(d)}');
          checked++;
          if (got.isNotEmpty) nonEmpty++;
        }
      }
    }
    expect(checked, greaterThan(3000));
    expect(nonEmpty, greaterThan(5));
  });

  test('lessonStatus совпадает с TS', () {
    final status = (fx['statusCases'] as Map).cast<String, String>();
    final bells = pkgs['ПИ-25а']!.bells!.weekday;
    for (final e in status.entries) {
      final p = e.key.split('|');
      final bell = bells.firstWhere((b) => b.num == int.parse(p[0]));
      final st = lessonStatus(
        bell: bell,
        override: p[1].isEmpty ? null : p[1],
        change: p[2].isEmpty ? null : p[2],
        teacherPending: false,
        minuteOfDay: double.parse(p[3]),
        when: DayRelation.values.firstWhere((w) => w.name == p[4]),
        cancelled: p[5] == 'true',
      );
      final got = [st.phase.name, st.label, st.minutes ?? '', st.progress?.toStringAsFixed(6) ?? '', st.replaced, st.extra].join('|');
      expect(got, e.value, reason: e.key);
    }
    expect(status.length, greaterThan(1000));
  });

  test('функции заметок совпадают с TS', () {
    final want = (fx['noteCases'] as Map).cast<String, String>();
    for (var i = 0; i < textSamples.length; i++) {
      final t = textSamples[i];
      expect(jsonEncode([for (final l in parseLines(t)) [l.index, l.isTodo ? 'todo' : 'text', l.checked, l.text]]), want['lines#$i'], reason: 'lines $i');
      final pr = progress(t);
      expect(jsonEncode({'done': pr.done, 'total': pr.total}), want['progress#$i'], reason: 'progress $i');
      expect(addChecklistItem(t), want['add#$i'], reason: 'add $i');
      expect(noteTitle(Note(id: 'x', title: '', text: t, updatedAt: '')), want['title#$i'], reason: 'title $i');
      expect(noteTitle(Note(id: 'x', title: '  Свой  ', text: t, updatedAt: '')), want['title2#$i'], reason: 'title2 $i');
      for (var k = 0; k < 5; k++) {
        expect(toggleLine(t, k), want['toggle#$i#$k'], reason: 'toggle $i $k');
      }
    }
    final pairs = [
      ['☐ a', '☐ a$nl'],
      ['☐ ', '☐ $nl'],
      ['☑ ', '☑ $nl'],
      ['abc', 'abc$nl'],
      ['x$nl☑ y', 'x$nl☑ y$nl'],
      ['a', 'ab'],
      ['', nl],
    ];
    for (var i = 0; i < pairs.length; i++) {
      expect(autoContinue(pairs[i][0], pairs[i][1]), want['continue#$i'], reason: 'continue $i');
    }
  });

  test('заметки к паре: с датой — только этого дня, без даты — ко всем повторам', () {
    final want = (fx['noteCases'] as Map).cast<String, String>();
    final notes = [for (final n in fx['notes'] as List) Note.fromJson(n as Map<String, dynamic>)];
    for (final (key, date) in [('k1', '2026-10-23'), ('k1', '2026-10-30'), ('k2', '2026-10-23'), ('k3', '2026-10-23'), (null, '2026-10-23')]) {
      expect(notesForLesson(notes, key, date).map((n) => n.id).join(','), want['for#${key ?? 'undefined'}#$date'], reason: '$key $date');
    }
  });

  test('buildingOf и rankLabel совпадают с TS', () {
    final want = (fx['lessonCases'] as Map).cast<String, String>();
    for (final l in pkgs['ПИ-25а']!.lessons) {
      final got = '${buildingOf(l) ?? ''}|${rankLabel(l.teachers.isEmpty ? null : l.teachers.first.rank)}';
      expect(got, want['${l.day}-${l.num}-${l.subgroup}-${l.subject}'], reason: l.subject);
    }
    for (final r in ['асс.', 'доц', 'проф.', 'ст.пр.', 'ст. пр.', 'преп', 'зав.каф.', 'неизвестно', '', 'ДОЦ.']) {
      expect(rankLabel(r), want['rank#$r'], reason: 'rank $r');
    }
  });
}
