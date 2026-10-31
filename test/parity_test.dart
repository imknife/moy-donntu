import 'dart:convert';
import 'dart:io';

import 'package:flutter_lab/domain/models.dart';
import 'package:flutter_lab/domain/schedule.dart';
import 'package:flutter_lab/domain/time_utils.dart';
import 'package:flutter_test/flutter_test.dart';

String sig(List<DayLesson> items) => items
    .map((i) => [i.key, i.num, i.lesson.subgroup, i.lesson.kind, i.override ?? '', i.overrideNote ?? '', i.change ?? '', i.bell.start, i.bell.end].join('|'))
    .join(';');

void main() {
  final fx = jsonDecode(File('test/fixtures/parity.json').readAsStringSync()) as Map<String, dynamic>;
  final raw = jsonDecode(File('test/fixtures/packages.json').readAsStringSync()) as Map<String, dynamic>;
  final pkgs = {for (final e in raw.entries) e.key: GroupPackage.fromJson(e.value as Map<String, dynamic>)};
  final now = DateTime.parse(fx['now'] as String);
  final start = parseYmd(fx['start'] as String)!;
  final days = fx['days'] as int;
  final cases = (fx['cases'] as Map).cast<String, String>();
  final meta = (fx['meta'] as Map).cast<String, String>();

  test('lessonsForDate совпадает с TS на всех пакетах, подгруппах и датах', () {
    var checked = 0;
    final bad = <String>[];
    for (final code in pkgs.keys) {
      for (final sub in [0, 1, 2]) {
        for (var i = 0; i < days; i++) {
          final d = addDays(start, i);
          final items = lessonsForDate(pkgs[code]!, d, sub, now);
          final got = '${sig(items)}~${pairsCount(items)}';
          final key = '$code#$sub#${ymd(d)}';
          checked++;
          if (cases[key] != got) bad.add('$key\n  ts:   ${cases[key]}\n  dart: $got');
          if (i % 7 == 3) {
            final n = nextStudyDay(pkgs[code]!, d, sub, now);
            final g = n == null ? 'null' : '${ymd(n.date)}~${sig(n.items)}';
            final k = 'next#$key'.replaceFirst('next#$code#$sub#', 'next#$code#$sub#');
            checked++;
            if (cases['next#$code#$sub#${ymd(d)}'] != g) bad.add('$k\n  ts:   ${cases['next#$code#$sub#${ymd(d)}']}\n  dart: $g');
          }
        }
      }
    }
    expect(bad.take(5).toList(), isEmpty);
    expect(checked, greaterThan(4000));
  });

  test('чётность недели, праздники и периоды совпадают с TS', () {
    var checked = 0;
    for (final code in pkgs.keys) {
      for (var i = 0; i < days; i++) {
        final d = addDays(start, i);
        final p = pkgs[code]!;
        final got = '${weekTypeFor(d, p.semesterStart)}|${dayOff(p, d) ?? ''}|${isoDay(d)}|${formatDayDate(d)}';
        expect(got, meta['$code#${ymd(d)}'], reason: '$code ${ymd(d)}');
        checked++;
      }
    }
    expect(checked, days * pkgs.length);
  });

  test('describeChange совпадает с TS', () {
    final want = (fx['describe'] as Map).cast<String, String?>();
    final changes = pkgs['СИНТ']!.lastChange!.changes;
    for (var i = 0; i < changes.length; i++) {
      expect(describeChange(changes[i]), want['$i'], reason: 'изменение $i');
    }
    expect(want.values.whereType<String>().length, greaterThan(3));
  });

  test('pluralLessons и formatDuration совпадают с TS', () {
    final misc = (fx['misc'] as Map).cast<String, String>();
    for (final n in [0, 1, 2, 3, 4, 5, 11, 12, 14, 21, 22, 25]) {
      expect(pluralLessons(n), misc['pl$n']);
    }
    for (final n in [0, 5, 45, 59, 60, 65, 125, 180]) {
      expect(formatDuration(n), misc['dur$n']);
    }
  });

  test('в фикстурах есть замены, отмены и свежие изменения (проверка самой проверки)', () {
    final all = cases.values.join(' ');
    expect(all.contains('|replace|'), isTrue);
    expect(all.contains('|add|'), isTrue);
    expect(all.contains('Замена:'), isTrue);
    expect(all.contains('Аудитория: 11.243, 11.244'), isTrue);
  });
}
