import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_lab/app.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  final dir = Platform.environment['SHOT_DIR'];
  setUpAll(loadFonts);

  testWidgets('снимки экранов в PNG (только при SHOT_DIR)', (tester) async {
    if (dir == null) return;
    final key = GlobalKey();
    Future<void> shot(String name) async {
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$dir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      });
    }

    for (final dark in [false, true]) {
      final suffix = dark ? 'dark' : 'light';
      final c = await makeController(
        group: 'ПИ-25а',
        subgroup: 1,
        stored: {'preferences': '{"theme":"$suffix","onboarded":true}'},
      );
      await tester.binding.setSurfaceSize(const Size(420, 900));
      await tester.pumpWidget(RepaintBoundary(key: key, child: App(controller: c)));
      await tester.pump();
      await shot('day_$suffix');
      await tester.tap(find.bySemanticsLabel('Что показывать'));
      await shot('filter_$suffix');
      await tester.tap(find.bySemanticsLabel('Закрыть'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ПИ-25а · 1 п/г'));
      await shot('group_$suffix');
      await tester.tap(find.bySemanticsLabel('Закрыть'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Алгоритмы и структуры данных').first);
      await shot('lesson_$suffix');
      await tester.ensureVisible(find.text('Заметка'));
      await tester.tap(find.text('Заметка'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '☐ Взять ноутбук\n☑ Сдать отчёт\nСпросить про зачёт');
      await shot('note_$suffix');
      await tester.ensureVisible(find.text('Готово'));
      await tester.tap(find.text('Готово'));
      await shot('lesson_note_$suffix');
      await tester.ensureVisible(find.text('Дедлайн'));
      await tester.tap(find.text('Дедлайн'));
      await shot('deadline_$suffix');
      await tester.enterText(find.byType(TextField).first, 'Сдать лабораторную');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Сохранить'));
      await tester.tap(find.text('Сохранить'));
      await shot('lesson_deadline_$suffix');
      await tester.pumpWidget(const SizedBox());
    }
    final c = await makeController(group: 'ПИ-25а', subgroup: 1, stored: {'preferences': '{"onboarded":true}'});
    await tester.pumpWidget(RepaintBoundary(key: key, child: App(controller: c)));
    await tester.pump();
    for (final tab in ['Профиль', 'Сервисы', 'Обзор']) {
      final handle = tester.ensureSemantics();
      await tester.tap(find.bySemanticsLabel(tab));
      await shot('tab_$tab');
      handle.dispose();
    }
    await tester.tap(find.bySemanticsLabel('Обзор'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await shot('overview_low');
    await tester.pumpWidget(const SizedBox());
  });
}
