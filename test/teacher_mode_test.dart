import 'dart:convert';

import 'package:flutter_lab/data/store.dart';
import 'package:flutter_lab/data/teacher_package.dart';
import 'package:flutter_lab/domain/directory.dart';
import 'package:flutter_lab/domain/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  setUpAll(loadFonts);

  test('выбранный преподаватель переживает сохранение настроек', () {
    final prefs = const Prefs().copyWith(activeTeacher: 'Иванова Е. С.', savedTeachers: ['Иванова Е. С.']);
    final back = Prefs.fromJson(jsonDecode(jsonEncode(prefs.toJson())) as Map<String, dynamic>);
    expect(back.activeTeacher, 'Иванова Е. С.');
    expect(back.savedTeachers, ['Иванова Е. С.']);
    expect(Prefs.fromJson(const {}).activeTeacher, '');
  });

  test('расписание преподавателя собирается в пакет: пара, аудитория, потоковые группы', () {
    final pkg = teacherPackage(
      'Иванова Е. С.',
      [
        SharedLesson(day: 1, num: 2, week: 'BOTH', subgroup: 0, subject: 'Математический анализ', kind: 'lecture', rooms: ['8.705'], teachers: ['Иванова Е. С.'], groups: ['ПИ-25а', 'ПИ-25б']),
      ],
      null,
    );
    final monday = DateTime.utc(2026, 10, 26);
    final items = lessonsForDate(pkg, monday, 0, monday);
    expect(items, hasLength(1));
    expect(items.single.num, 2);
    expect(items.single.lesson.teachers.single.name, 'Иванова Е. С.');
    expect(items.single.lesson.stream.map((g) => g.code), ['ПИ-25а', 'ПИ-25б']);
    expect(lessonsForDate(pkg, DateTime.utc(2026, 10, 27), 0, monday), isEmpty);
  });

  test('в расписании преподавателя у пары остаются все преподаватели, а не только выбранный', () {
    final pkg = teacherPackage(
      'Иванова Е. С.',
      [
        SharedLesson(day: 1, num: 2, week: 'BOTH', subgroup: 0, subject: 'Практика', kind: 'practice', rooms: ['8.705'], teachers: ['Иванова Е. С.', 'Петров А. Б.'], groups: ['ПИ-25а']),
        SharedLesson(day: 1, num: 3, week: 'BOTH', subgroup: 0, subject: 'Лекция', kind: 'lecture', rooms: [], teachers: [], groups: ['ПИ-25а']),
      ],
      null,
    );
    final monday = DateTime.utc(2026, 10, 26);
    final items = lessonsForDate(pkg, monday, 0, monday);
    expect(teachersLabel(items[0].lesson), 'Иванова Е. С., Петров А. Б.');
    expect(teachersLabel(items[1].lesson), 'Иванова Е. С.');
  });

  testWidgets('первый запуск: выбор преподавателя открывает приложение, все вкладки без исключений', (tester) async {
    final handle = tester.ensureSemantics();
    const name = 'Агарков А.В.';
    Future<void> settle() async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
      await tester.pump(const Duration(milliseconds: 400));
    }

    final c = await makeController(stored: {'preferences': jsonEncode({'savedTeachers': [name]})});
    await pumpApp(tester, c);
    expect(c.model.value, isNull);
    expect(find.text('Выберите группу'), findsOneWidget);
    await tester.tap(find.text('Преподаватели'));
    await settle();
    final full = c.names[name];
    expect(full, 'Агарков Александр Владиславович');
    expect(find.textContaining(full!), findsWidgets);
    await tester.tap(find.textContaining('Агарков').first);
    await settle();
    expect(c.store.prefs.value.activeTeacher, name);
    expect(c.store.prefs.value.onboarded, isTrue);
    expect(c.model.value, isNull);
    expect(find.text('Выберите группу'), findsNothing);
    for (final label in ['Обзор', 'Расписание', 'Сервисы', 'Профиль']) {
      await tester.tap(find.bySemanticsLabel(label));
      await settle();
      expect(tester.takeException(), isNull, reason: label);
    }
    handle.dispose();
    await unmount(tester);
  });
}
