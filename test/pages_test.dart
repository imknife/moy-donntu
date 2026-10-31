import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_lab/data/store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

Future<void> go(WidgetTester tester, String location) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  navigator.pushNamed(location);
  await tester.pumpAndSettle();
}

Future<void> wait(WidgetTester tester) => settleIsolates(tester);

void main() {
  setUpAll(loadFonts);

  testWidgets('обзор: карточка пары, нагрузка недели, изменения, избранные сервисы', (tester) async {
    final c = await makeController(group: 'ПИ-25а', subgroup: 1);
    await pumpApp(tester, c);
    await tester.tap(find.bySemanticsLabel('Обзор'));
    await tester.pumpAndSettle();
    expect(find.text('23'), findsWidgets);
    expect(find.text('Пятница'), findsOneWidget);
    expect(find.textContaining('Осталось'), findsOneWidget);
    expect(find.textContaining('Алгоритмы и структуры данных'), findsWidgets);
    expect(find.textContaining('ауд.'), findsOneWidget);
    expect(find.text('ДАЛЬШЕ'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('БЫСТРЫЕ ДЕЙСТВИЯ'), 300);
    expect(find.text('Нагрузка недели'), findsNothing);
    expect(find.text('Студенческий билет'), findsNothing);
    expect(find.text('НА СЕГОДНЯ'), findsNothing);
    await unmount(tester);
  });

  testWidgets('сервисы: избранное редактируется и сохраняется', (tester) async {
    final c = await makeController(group: 'ПИ-25а', subgroup: 1);
    await pumpApp(tester, c);
    await tester.tap(find.bySemanticsLabel('Сервисы'));
    await tester.pumpAndSettle();
    expect(find.text('Зачётная книжка'), findsWidgets);
    expect(find.text('банк знаний'), findsNothing);
    await tester.tap(find.text('ИЗМЕНИТЬ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Заметки'));
    await tester.pumpAndSettle();
    expect(c.store.prefs.value.quickServices, contains('notes'));
    await unmount(tester);
  });

  testWidgets('преподаватели и аудитории отвечают из встроенных расписаний без сети', (tester) async {
    final c = await makeController(group: 'ПИ-25а', subgroup: 1);
    await pumpApp(tester, c);
    await go(tester, '/teachers');
    await pumpUntilFound(tester, find.textContaining('Бурлаева'));
    expect(find.text('Преподаватели'), findsWidgets);
    expect(find.textContaining('Бурлаева'), findsWidgets);
    await tester.enterText(find.byType(TextField), 'бурлаева');
    await tester.pumpAndSettle();
    expect(find.textContaining('Бурлаева'), findsOneWidget);
    expect(find.textContaining('Дмитрюк'), findsNothing);
    await unmount(tester);
  });

  testWidgets('свободные аудитории и страница аудитории', (tester) async {
    final c = await makeController(group: 'ПИ-25а', subgroup: 1);
    await pumpApp(tester, c);
    await go(tester, '/rooms');
    await pumpUntilFound(tester, find.textContaining('Корпус 4'));
    expect(find.text('Свободные аудитории'), findsOneWidget);
    expect(find.text('СВОБОДНО СЕЙЧАС'), findsOneWidget);
    expect(find.textContaining('Корпус'), findsWidgets);
    await go(tester, '/room?room=8.705&date=2026-10-23');
    await pumpUntilFound(tester, find.textContaining('Корпус 8'));
    expect(find.text('Аудитория 8.705'), findsOneWidget);
    expect(find.textContaining('Корпус 8'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('поиск: группы, недавнее', (tester) async {
    final c = await makeController(group: 'ПИ-25а', subgroup: 1);
    await pumpApp(tester, c);
    await go(tester, '/search');
    await tester.tap(find.text('Группы'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ПИ-25б');
    await tester.pumpAndSettle();
    await tester.tap(find.text('ПИ-25б').last);
    await wait(tester);
    expect(c.store.recents.value.single.title, 'ПИ-25б');
    expect(find.textContaining('Чужая группа'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('просмотр чужой группы и «Сделать моей»', (tester) async {
    final c = await makeController(group: 'ПИ-25а', subgroup: 1);
    await pumpApp(tester, c);
    await go(tester, '/group?group=ПИ-25б');
    await wait(tester);
    expect(find.text('Сделать моей'), findsOneWidget);
    await tester.tap(find.text('Сделать моей'));
    await wait(tester);
    expect(c.store.selection.value.group, 'ПИ-25б');
    await unmount(tester);
  });

  testWidgets('мои расписания: список групп и выбор подгруппы', (tester) async {
    final c = await makeController(group: 'ПИ-25а', subgroup: 0);
    await pumpApp(tester, c);
    await go(tester, '/groups');
    expect(find.text('Мои расписания'), findsOneWidget);
    await tester.tap(find.text('2 подгруппа'));
    await tester.pumpAndSettle();
    expect(c.store.selection.value.subgroup, 2);
    await unmount(tester);
  });

  testWidgets('общий список заметок: фильтры, закрепление, поиск', (tester) async {
    final stored = {
      'notes': jsonEncode([
        {'id': 'a', 'title': 'Лаба', 'text': 'сдать отчёт', 'lessonKey': 'k1', 'subject': 'Алгоритмы', 'kind': 'lab', 'updatedAt': DateTime.now().toUtc().toIso8601String()},
        {'id': 'b', 'title': 'Покупки', 'text': 'хлеб', 'updatedAt': DateTime.now().toUtc().toIso8601String(), 'pinned': true},
      ]),
    };
    final c = await makeController(group: 'ПИ-25а', subgroup: 1, stored: stored);
    await pumpApp(tester, c);
    await go(tester, '/notes');
    expect(find.text('Закреплённые'), findsOneWidget);
    expect(find.text('Покупки'), findsOneWidget);
    await tester.tap(find.text('К парам'));
    await tester.pumpAndSettle();
    expect(find.text('Покупки'), findsNothing);
    expect(find.text('Лаба'), findsOneWidget);
    await tester.tap(find.text('Все'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'хлеб');
    await tester.pumpAndSettle();
    expect(find.text('Лаба'), findsNothing);
    await unmount(tester);
  });

  testWidgets('настройки, оформление, экран при запуске, данные, о приложении', (tester) async {
    final c = await makeController(group: 'ПИ-25а', subgroup: 1);
    await pumpApp(tester, c);
    await go(tester, '/start-screen');
    await tester.tap(find.text('Обзор'));
    await tester.pumpAndSettle();
    expect(c.store.prefs.value.startScreen, 'overview');
    await go(tester, '/appearance');
    await tester.tap(find.text('Крупный'));
    await tester.pumpAndSettle();
    expect(c.store.prefs.value.largeText, isTrue);
    await go(tester, '/settings');
    expect(find.text('Скрывать прошедшие пары'), findsOneWidget);
    await go(tester, '/privacy');
    expect(find.text('Обновлять автоматически'), findsOneWidget);
    await go(tester, '/about');
    expect(find.text('Расписание пар'), findsWidgets);
    expect(find.textContaining('Расписание от '), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('звонки, учебный график, сессия, ссылки, изменения', (tester) async {
    final c = await makeController(group: 'ПИ-25а', subgroup: 1);
    await pumpApp(tester, c);
    await go(tester, '/bells');
    await wait(tester);
    expect(find.textContaining('8:00 – 9:35'), findsOneWidget);
    await go(tester, '/academic');
    await wait(tester);
    expect(find.text('ПЕРИОДЫ'), findsOneWidget);
    await go(tester, '/session');
    await wait(tester);
    expect(find.textContaining('ДО СЕССИИ'), findsOneWidget);
    await go(tester, '/links');
    expect(find.text('Сайт ДонНТУ'), findsOneWidget);
    await go(tester, '/changes');
    await wait(tester);
    await unmount(tester);
  });

  testWidgets('неизвестный адрес и закрытые флагами разделы', (tester) async {
    final c = await makeController(group: 'ПИ-25а', subgroup: 1);
    await pumpApp(tester, c);
    await go(tester, '/нет-такой');
    expect(find.text('Страница не найдена'), findsWidgets);
    await tester.tap(find.text('Открыть расписание'));
    await tester.pumpAndSettle();
    await go(tester, '/knowledge');
    expect(find.text('Страница не найдена'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('страница пары открывается по ссылке с параметрами', (tester) async {
    final c = await makeController(group: 'ПИ-25а', subgroup: 1);
    await pumpApp(tester, c);
    await go(tester, '/lesson?date=2026-10-23&group=ПИ-25а&sub=1&slot=2&key=2-0-Алгоритмы и структуры данных');
    expect(find.text('Боднар Алина Валериевна'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('профиль: имя сохраняется и показывается', (tester) async {
    final c = await makeController(group: 'ПИ-25а', subgroup: 1);
    await pumpApp(tester, c);
    await go(tester, '/edit-profile');
    await tester.enterText(find.byType(TextField), 'Иван Иванов');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(c.store.prefs.value.displayName, 'Иван Иванов');
    expect(c.store.prefs.value.theme, ThemeChoice.system);
    await unmount(tester);
  });
}
