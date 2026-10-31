import 'package:flutter_lab/domain/ace.dart';
import 'package:flutter_lab/domain/grades.dart';
import 'package:flutter_test/flutter_test.dart';

ZachRow row(String form, {num? hours, num? zet, int mark = 5, int sem = 2, String dis = 'Объектно-ориентированное программирование'}) => ZachRow(
      dis: dis,
      controlForm: form,
      mark: 'Отлично',
      markNumber: mark,
      sem: sem,
      course: 1,
      hours: hours,
      zet: zet,
      teacherName: null,
      dateExam: '2026-06-25',
      year: '2025-2026',
    );

void main() {
  test('курсовой проект сворачивается в строку своей дисциплины', () {
    final exam = row('Экзамен', hours: 216, zet: 6);
    final project = row('Курсовой проект', hours: 0, zet: 0);
    final other = row('Экзамен', hours: 72, zet: 2, dis: 'Физика');
    final groups = groupCourseWork([project, exam, other]);
    expect(groups.length, 2);
    expect(groups[0].$1, exam);
    expect(groups[0].$2, [project]);
    expect(groups[1].$1, other);
    expect(gradeMeta(exam, extras: groups[0].$2), contains('курсовой проект 5'));
  });

  test('курсовой проект без экзамена в том же семестре остаётся отдельной строкой', () {
    final project = row('Курсовой проект', hours: 0, zet: 0);
    final groups = groupCourseWork([project]);
    expect(groups.length, 1);
    expect(groups[0].$1, project);
    expect(groups[0].$2, isEmpty);
  });

  test('нулевой объём не показывается', () {
    expect(gradeMeta(row('Курсовой проект', hours: 0, zet: 0)), isNot(contains('0 ч')));
    expect(gradeMeta(row('Курсовой проект', hours: 0, zet: 0)), isNot(contains('з.е.')));
    expect(volumeLabel(row('Экзамен', hours: 216, zet: 6)), '6 з.е.');
    expect(volumeLabel(row('Экзамен', hours: 216)), '216 ч');
  });
}
