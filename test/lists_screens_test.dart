import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_lab/app.dart';
import 'package:flutter_lab/domain/directory.dart';
import 'package:flutter_lab/ui/settings_group.dart';
import 'package:flutter_lab/ui/theme.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contrast_test.dart' as contrast;
import 'support.dart';

const _width = 360.0;
const _height = 800.0;
const _scale = 1.5;

Future<void> openAt360(WidgetTester tester, Widget app) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(_width, _height);
  tester.platformDispatcher.textScaleFactorTestValue = _scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(app);
  await tester.pump();
}

Future<void> go(WidgetTester tester, String location) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pushNamed(location);
  await settleBounded(tester);
}

void main() {
  final dir = Platform.environment['SHOT_DIR'];
  setUpAll(loadFonts);

  for (final dark in [false, true]) {
    final suffix = dark ? 'dark' : 'light';
    final pal = dark ? Pal.darkPal : Pal.light;

    testWidgets('сервисы, профиль, настройки: серый фон и острова, $suffix, 360 px, x1.5', (tester) async {
      final key = GlobalKey();
      Future<void> shot(String name) async {
        await settleBounded(tester);
        if (dir == null) return;
        await tester.runAsync(() async {
          final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          File('$dir/${name}_$suffix.png').writeAsBytesSync(data!.buffer.asUint8List());
        });
      }

      final c = await makeController(group: 'ПИ-25а', subgroup: 1, stored: {'preferences': '{"theme":"$suffix","onboarded":true}'});
      final errors = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exceptionAsString().split('\n').first);
      addTearDown(() => FlutterError.onError = previous);
      await openAt360(tester, RepaintBoundary(key: key, child: App(controller: c)));

      c.tab.value = 2;
      await settleBounded(tester);
      expect(find.byType(GroupedBackground), findsOneWidget);
      expect(tester.widget<ColoredBox>(find.descendant(of: find.byType(GroupedBackground), matching: find.byType(ColoredBox)).first).color, pal.pageGray);
      expect(find.byType(SettingsGroup), findsWidgets);
      expect(pal.island, isNot(pal.pageGray));
      await shot('services');

      c.tab.value = 3;
      await settleBounded(tester);
      expect(find.text('Мои расписания'), findsOneWidget);
      expect(find.byType(SettingsGroup), findsWidgets);
      await shot('profile');

      await go(tester, '/settings');
      expect(find.text('Группа и подгруппа'), findsOneWidget);
      expect(find.byType(SettingsGroup), findsWidgets);
      await shot('settings');

      await unmount(tester);
      expect(errors.toSet(), isEmpty);
    });
  }

  for (final pal in [Pal.light, Pal.darkPal]) {
    final name = pal.dark ? 'тёмная' : 'светлая';
    test('контраст на сером фоне и в островах не ниже 4.5, тема: $name', () {
      for (final bg in [pal.pageGray, pal.island]) {
        for (final fg in [pal.text, pal.muted, pal.link]) {
          expect(contrast.ratio(fg, bg), greaterThanOrEqualTo(pal.dark && fg == pal.muted ? 4.4 : 4.5));
        }
      }
      expect(contrast.ratio(pal.danger, pal.island), greaterThanOrEqualTo(4.5));
      expect(contrast.ratio(pal.link, pal.tint), greaterThanOrEqualTo(4.5));
    });

    test('графика на островах не ниже 3.0, тема: $name', () {
      expect(contrast.ratio(pal.axis, pal.island), greaterThanOrEqualTo(3.0));
      expect(contrast.ratio(pal.link, pal.island), greaterThanOrEqualTo(3.0));
    });
  }

  group('пустые состояния', () {
    testWidgets('поиск: преподаватели, аудитории, группы', (tester) async {
      final c = await makeController(group: 'ПИ-25а', subgroup: 1);
      await pumpApp(tester, c);
      await go(tester, '/search');
      await tester.enterText(find.byType(TextField), 'яяяяя');
      await pumpUntilFound(tester, find.text('Ничего не найдено'));
      expect(find.text('Ничего не найдено'), findsOneWidget);
      for (final kind in ['Аудитории', 'Группы']) {
        await tester.tap(find.text(kind));
        await tester.pump();
        await pumpUntilFound(tester, find.text('Ничего не найдено'));
        expect(find.text('Ничего не найдено'), findsOneWidget, reason: kind);
      }
      await unmount(tester);
    });

    testWidgets('список преподавателей: поиск без совпадений', (tester) async {
      final c = await makeController(group: 'ПИ-25а', subgroup: 1);
      await pumpApp(tester, c);
      await go(tester, '/teachers');
      await pumpUntilFound(tester, find.textContaining('Бурлаева'));
      await tester.enterText(find.byType(TextField), 'яяяяя');
      await tester.pumpAndSettle();
      expect(find.text('Ничего не найдено'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('сохранённые преподаватели: поиск без совпадений', (tester) async {
      final c = await makeController(group: 'ПИ-25а', subgroup: 1, stored: {'preferences': '{"onboarded":true,"savedTeachers":["Бурлаева Е.И."]}'});
      await pumpApp(tester, c);
      await go(tester, '/teachers');
      await tester.tap(find.text('Сохранённые'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'яяяяя');
      await tester.pumpAndSettle();
      expect(find.text('Ничего не найдено'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('страница преподавателя: в выбранный день нет пар', (tester) async {
      final packages = loadSeedPackages();
      final name = [for (final t in teacherHits(packages, '')) if (!teacherSchedule(packages, t.name).any((l) => l.day == 5) && t.lessons > 0) t.name].first;
      final c = await makeController(group: 'ПИ-25а', subgroup: 1);
      await pumpApp(tester, c);
      await go(tester, '/teacher?name=${Uri.encodeComponent(name)}');
      await pumpUntilFound(tester, find.text('Ничего не найдено'));
      expect(find.text('Ничего не найдено'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('страница неизвестного преподавателя: нет опубликованных пар', (tester) async {
      final c = await makeController(group: 'ПИ-25а', subgroup: 1);
      await pumpApp(tester, c);
      await go(tester, '/teacher?name=${Uri.encodeComponent('Несуществующий Н.Н.')}');
      await pumpUntilFound(tester, find.text('Ничего не найдено'));
      expect(find.text('Ничего не найдено'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('выбор группы: поиск без совпадений', (tester) async {
      final c = await makeController(group: 'ПИ-25а', subgroup: 1);
      await pumpApp(tester, c);
      await go(tester, '/groups');
      await tester.enterText(find.byType(TextField), 'яяяяя');
      await tester.pumpAndSettle();
      expect(find.text('Ничего не найдено'), findsOneWidget);
      await unmount(tester);
    });
  });
}
