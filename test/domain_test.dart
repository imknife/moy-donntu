import 'package:flutter_lab/domain/models.dart';
import 'package:flutter_lab/domain/schedule.dart';
import 'package:flutter_lab/domain/time_utils.dart';
import 'package:flutter_test/flutter_test.dart';

Lesson lesson(int day, int num, {String week = 'BOTH', int sub = 0, String subject = 'Предмет', String kind = 'lecture'}) =>
    Lesson(day: day, num: num, week: week, subgroup: sub, subject: subject, kind: kind, rooms: const [], teachers: const []);

GroupPackage pkg(List<Lesson> lessons, {List<Override> overrides = const [], AcademicCalendar? calendar, BellGrids? bells}) => GroupPackage(
      code: 'Т-1',
      semesterStart: '2026-09-01',
      bells: bells,
      calendar: calendar,
      lessons: lessons,
      overrides: overrides,
      lastChange: null,
    );

final now = DateTime.utc(2026, 10, 25, 12);

void main() {
  test('toMsk: 22:30 UTC в субботу уже воскресенье по Москве', () {
    final m = toMsk(DateTime.utc(2026, 10, 24, 22, 30));
    expect([m.year, m.month, m.day, m.hour, m.minute], [2026, 10, 25, 1, 30]);
    expect(isoDay(m), 7);
  });

  test('первая неделя семестра верхняя, дальше чередуются', () {
    expect(weekTypeFor(dateOf(2026, 9, 1), '2026-09-01'), 'UPPER');
    expect(weekTypeFor(dateOf(2026, 9, 6), '2026-09-01'), 'UPPER');
    expect(weekTypeFor(dateOf(2026, 9, 7), '2026-09-01'), 'LOWER');
    expect(weekTypeFor(dateOf(2026, 10, 23), '2026-09-01'), 'LOWER');
    expect(weekTypeFor(dateOf(2026, 10, 26), '2026-09-01'), 'UPPER');
    expect(weekTypeFor(dateOf(2026, 9, 8), null), 'LOWER');
  });

  test('неделя считается от понедельника, не от даты', () {
    expect(startOfIsoWeek(dateOf(2026, 10, 25)), dateOf(2026, 10, 19));
    expect(startOfIsoWeek(dateOf(2026, 10, 19)), dateOf(2026, 10, 19));
    expect(addDays(dateOf(2026, 10, 31), 1), dateOf(2026, 11, 1));
  });

  test('подгруппа: 0 видит всё, 1 не видит пару второй подгруппы', () {
    final p = pkg([lesson(5, 1, sub: 1, subject: 'A'), lesson(5, 1, sub: 2, subject: 'B'), lesson(5, 2, subject: 'C')]);
    final fri = dateOf(2026, 10, 23);
    expect(lessonsForDate(p, fri, 0, now).map((e) => e.lesson.subject), ['A', 'B', 'C']);
    expect(lessonsForDate(p, fri, 1, now).map((e) => e.lesson.subject), ['A', 'C']);
    expect(lessonsForDate(p, fri, 2, now).map((e) => e.lesson.subject), ['B', 'C']);
    expect(pairsCount(lessonsForDate(p, fri, 0, now)), 2);
  });

  test('чётная и нечётная недели не смешиваются', () {
    final p = pkg([lesson(5, 1, week: 'UPPER', subject: 'в'), lesson(5, 2, week: 'LOWER', subject: 'н')]);
    expect(lessonsForDate(p, dateOf(2026, 10, 23), 0, now).map((e) => e.lesson.subject), ['н']);
    expect(lessonsForDate(p, dateOf(2026, 10, 30), 0, now).map((e) => e.lesson.subject), ['в']);
  });

  test('звонки: выходные по своей сетке, запасные — если в пакете нет', () {
    final p = pkg([lesson(6, 2), lesson(5, 2)]);
    expect(lessonsForDate(p, dateOf(2026, 10, 24), 0, now).single.bell.start, '09:45');
    expect(lessonsForDate(p, dateOf(2026, 10, 23), 0, now).single.bell.start, '09:55');
    final custom = BellGrids(
      weekday: [const Bell(num: 2, start: '10:00', end: '11:35', startMinutes: 600, endMinutes: 695)],
      weekend: const [],
    );
    final q = pkg([lesson(5, 2), lesson(6, 2)], bells: custom);
    expect(lessonsForDate(q, dateOf(2026, 10, 23), 0, now).single.bell.start, '10:00');
    expect(lessonsForDate(q, dateOf(2026, 10, 24), 0, now), isEmpty);
  });

  test('праздник и сессия гасят сетку, но не разовые замены', () {
    const cal = AcademicCalendar(
      periods: [Period(kind: 'study', from: '2026-09-01', to: '2026-12-23'), Period(kind: 'exams', from: '2027-01-11', to: '2027-01-31')],
      holidays: [Holiday(date: '2026-11-04', name: 'День народного единства')],
    );
    final add = Override(id: 1, date: '2026-11-04', num: 3, subgroup: 0, action: 'add', lesson: lesson(0, 3, subject: 'Разовая'), note: null);
    final p = pkg([lesson(3, 1), lesson(1, 1)], calendar: cal, overrides: [add]);
    final holiday = dateOf(2026, 11, 4);
    expect(dayOff(p, holiday), 'День народного единства');
    expect(lessonsForDate(p, holiday, 0, now).map((e) => e.lesson.subject), ['Разовая']);
    expect(dayOff(p, dateOf(2027, 1, 12)), 'Сессия');
    expect(lessonsForDate(p, dateOf(2027, 1, 13), 0, now), isEmpty);
    expect(dayOff(p, dateOf(2026, 11, 5)), isNull);
  });

  test('отмена убирает пару, замена подменяет, порядок по номеру', () {
    final p = pkg([lesson(5, 1, subject: 'A'), lesson(5, 2, subject: 'B')], overrides: [
      const Override(id: 1, date: '2026-10-23', num: 1, subgroup: 0, action: 'cancel', lesson: null, note: null),
      Override(id: 2, date: '2026-10-23', num: 2, subgroup: 0, action: 'replace', lesson: lesson(0, 2, subject: 'Новая'), note: 'причина'),
    ]);
    final items = lessonsForDate(p, dateOf(2026, 10, 23), 0, now);
    expect(items.map((e) => e.lesson.subject), ['Новая']);
    expect(items.single.override, 'replace');
    expect(isReplaced(items.single), isTrue);
    expect(changeChip(items.single), isNull);
  });

  test('отмена для одной подгруппы оставляет другую у общей пары', () {
    final p = pkg([lesson(5, 1, subject: 'Общая')], overrides: [
      const Override(id: 1, date: '2026-10-23', num: 1, subgroup: 1, action: 'cancel', lesson: null, note: null),
    ]);
    final all = lessonsForDate(p, dateOf(2026, 10, 23), 0, now);
    expect(all.single.lesson.subgroup, 2);
    expect(lessonsForDate(p, dateOf(2026, 10, 23), 1, now), isEmpty);
    expect(lessonsForDate(p, dateOf(2026, 10, 23), 2, now).length, 1);
  });

  test('nextStudyDay пропускает пустые дни', () {
    final p = pkg([lesson(1, 1)]);
    final n = nextStudyDay(p, dateOf(2026, 10, 23), 0, now)!;
    expect(n.date, dateOf(2026, 10, 26));
    expect(nextStudyDay(pkg([]), dateOf(2026, 10, 23), 0, now), isNull);
  });

  test('describeChange: замена преподавателя, аудитория, предмет', () {
    String? d(FieldChange f) => describeChange(LessonChange(type: 'changed', day: 1, num: 1, week: 'BOTH', subgroup: 0, subject: 's', fields: [f]));
    expect(d(const FieldChange(field: 'teachers', from: 'доц. А Б.В.', to: 'асс. Г Д.Е.')), 'Замена: Г Д.Е.');
    expect(d(const FieldChange(field: 'rooms', from: '', to: '')), 'Аудитория: не указана');
    expect(d(const FieldChange(field: 'subject', from: 'a', to: 'b')), 'Другой предмет');
    expect(d(const FieldChange(field: 'kind', from: 'a', to: 'b')), 'Изменено');
  });

  test('текстовые утилиты: время, число пар, длительность, дата', () {
    expect(shortTime('08:00'), '8:00');
    expect(shortTime('11:30'), '11:30');
    expect(pluralLessons(1), '1 пара');
    expect(pluralLessons(3), '3 пары');
    expect(pluralLessons(5), '5 пар');
    expect(pluralLessons(11), '11 пар');
    expect(formatDuration(125), '2 ч 5 мин');
    expect(formatDuration(120), '2 ч');
    expect(formatDuration(45), '45 мин');
    expect(formatDayDate(dateOf(2026, 10, 23)), '23 октября');
  });
}
