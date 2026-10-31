import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_lab/data/store.dart';
import 'package:flutter_lab/domain/models.dart';
import 'package:flutter_lab/ui/day_pager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support.dart';

void main() {
  setUpAll(loadFonts);

  testWidgets('первый запуск: группа выбирается поиском и сохраняется', (tester) async {
    final c = await makeController();
    await pumpApp(tester, c);
    expect(find.text('Выберите группу'), findsOneWidget);
    expect(find.text('Неофициальное приложение'), findsNothing);
    expect(find.text('Войти через кабинет'), findsOneWidget);
    expect(c.groups.value.length, greaterThan(40));
    await tester.enterText(find.byType(TextField), 'пи-25а');
    await tester.pump();
    expect(find.text('ПИ-25б'), findsNothing);
    await tester.tap(find.text('ПИ-25а'));
    await settleIsolates(tester);
    expect(find.text('День'), findsOneWidget);
    expect(c.store.selection.value.group, 'ПИ-25а');
    expect(c.store.prefs.value.onboarded, isTrue);
    final sp = await SharedPreferences.getInstance();
    expect(jsonDecode(sp.getString('selection')!)['group'], 'ПИ-25а');
    await unmount(tester);
  });

  testWidgets('поиск группы: пустой результат', (tester) async {
    final c = await makeController();
    await pumpApp(tester, c);
    await tester.enterText(find.byType(TextField), 'яяяя');
    await tester.pump();
    expect(find.text('Ничего не найдено'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('день: шапка, текущая пара, свайп, плитка дня, режимы', (tester) async {
    final c = await makeController(group: 'ПИ-25а', subgroup: 1);
    await pumpApp(tester, c);
    expect(find.text('Пятница · нижняя неделя'), findsOneWidget);
    expect(find.text('ПИ-25а · 1 п/г'), findsOneWidget);
    expect(find.text('Идёт · ещё 1 ч 30 мин'), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Суббота · нижняя неделя'), findsOneWidget);
    expect(find.text('Свободный день'), findsOneWidget);
    await tester.tap(find.text('22'));
    await tester.pumpAndSettle();
    expect(find.text('Четверг · нижняя неделя'), findsOneWidget);
    await tester.tap(find.text('Неделя'));
    await tester.pumpAndSettle();
    expect(c.store.prefs.value.mode, 1);
    await tester.tap(find.text('Месяц'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('День'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('неделя: нажатие на занятие открывает страницу пары', (tester) async {
    final c = await makeController(group: 'ПИ-25а', subgroup: 1);
    await pumpApp(tester, c);
    await tester.tap(find.text('Неделя'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('открыть занятие')).first);
    await tester.pumpAndSettle();
    expect(find.text('Заметка'), findsWidgets);
    expect(find.text('Неделя'), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('страница пары и заметка сохраняются между запусками', (tester) async {
    final c = await makeController(group: 'ПИ-25а', subgroup: 1);
    await pumpApp(tester, c);
    await tester.tap(find.text('Алгоритмы и структуры данных').first);
    await tester.pumpAndSettle();
    expect(find.text('Боднар Алина Валериевна'), findsOneWidget);
    expect(find.text('9:55–11:30'), findsOneWidget);
    expect(find.text('1 ч 35 мин'), findsOneWidget);
    expect(find.text('ЛЕКЦИЯ'), findsOneWidget);
    await tester.ensureVisible(find.text('Заметка'));
    await tester.tap(find.text('Заметка'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Принести конспект');
    await tester.ensureVisible(find.text('Готово'));
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    expect(find.text('Принести конспект'), findsOneWidget);
    final saved = (await SharedPreferences.getInstance()).getString('notes')!;
    expect(saved, contains('Принести конспект'));
    await unmount(tester);

    final again = await makeController(group: 'ПИ-25а', subgroup: 1, stored: {'notes': saved});
    await pumpApp(tester, again);
    expect(find.text('Заметка'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('чеклист в заметке отмечается тапом', (tester) async {
    final c = await makeController(group: 'ПИ-25а', subgroup: 1);
    await pumpApp(tester, c);
    await tester.tap(find.text('Алгоритмы и структуры данных').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Заметка'));
    await tester.tap(find.text('Заметка'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Чеклист'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, '☐ Сдать лабу');
    await tester.ensureVisible(find.text('Готово'));
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сдать лабу'));
    await tester.pumpAndSettle();
    expect(c.store.notes.value.single.text, '☑ Сдать лабу');
    await unmount(tester);
  });

  testWidgets('строка пары: кабинет с меткой, без слов «ауд.» и «Замена»', (tester) async {
    final c = await makeController(group: 'ПИ-25а', subgroup: 1);
    await pumpApp(tester, c);
    expect(find.textContaining('ауд.'), findsNothing);
    expect(find.textContaining('Замена'), findsNothing);
    await unmount(tester);
  });

  testWidgets('отменённая пара показывается карточкой и скрывается настройкой', (tester) async {
    final cancel = Override(id: 1, date: '2026-10-23', num: 1, subgroup: 0, action: 'cancel', lesson: null, note: 'Болезнь');
    final c = await makeController(group: 'ПИ-25а', subgroup: 1, overrides: [cancel]);
    await pumpApp(tester, c);
    await tester.scrollUntilVisible(find.textContaining('1-я пара отменена'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Болезнь'), findsOneWidget);
    c.store.setPrefs((p) => p.copyWith(showCancelled: false));
    await tester.pumpAndSettle();
    expect(find.textContaining('1-я пара отменена'), findsNothing);
    await unmount(tester);
  });

  testWidgets('скрытие прошедших пар убирает закончившуюся пару', (tester) async {
    final c = await makeController(group: 'ПИ-25а', subgroup: 1);
    await pumpApp(tester, c);
    expect(find.text('Теория вероятностей и математическая статистика'), findsOneWidget);
    c.store.setPrefs((p) => p.copyWith(hidePast: true));
    await tester.pumpAndSettle();
    expect(find.text('Теория вероятностей и математическая статистика'), findsNothing);
    await unmount(tester);
  });

  testWidgets('профиль: тема и настройки сохраняются', (tester) async {
    final handle = tester.ensureSemantics();
    final c = await makeController(group: 'ПИ-25а', subgroup: 1);
    await pumpApp(tester, c);
    await tester.tap(find.bySemanticsLabel('Профиль'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Оформление'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Тёмная'));
    await tester.pumpAndSettle();
    expect(c.store.prefs.value.theme, ThemeChoice.dark);
    final sp = await SharedPreferences.getInstance();
    expect(jsonDecode(sp.getString('preferences')!)['theme'], 'dark');
    expect(find.text('Меньше движения'), findsNothing);
    expect(find.text('Шрифт'), findsNothing);
    expect(find.text('Иконки'), findsNothing);
    expect(find.text('Стиль текста'), findsNothing);
    expect(find.text('Строчные'), findsNothing);
    await tester.tap(find.text('Крупный'));
    await tester.pumpAndSettle();
    expect(c.store.prefs.value.largeText, isTrue);
    handle.dispose();
    await unmount(tester);
  });

  testWidgets('анимации отключены в системе: тап по дню переключает страницу сразу', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final c = await makeController(group: 'ПИ-25а', subgroup: 1);
    await pumpApp(tester, c);
    await tester.tap(find.text('25'));
    await tester.pump();
    final controller = tester.widget<PageView>(find.byType(PageView)).controller;
    expect(controller!.page, pageOf(DateTime.utc(2026, 10, 25)).toDouble());
    await unmount(tester);
  });

  testWidgets('шапка уезжает вверх вместе с прокруткой списка и возвращается при смене дня', (tester) async {
    final c = await makeController(group: 'ПИ-25а', subgroup: 1);
    await pumpApp(tester, c);
    await tester.binding.setSurfaceSize(const Size(420, 560));
    await tester.pumpAndSettle();
    final subtitle = find.text('Пятница · нижняя неделя');
    final before = tester.getTopLeft(subtitle).dy;
    await tester.drag(find.text('Алгоритмы и структуры данных').first, const Offset(0, -300));
    await tester.pump();
    expect(tester.getTopLeft(subtitle).dy, lessThan(before - 20));
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1500);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Суббота · нижняя неделя')).dy, closeTo(before, 1));
    await unmount(tester);
  });
}
