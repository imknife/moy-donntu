import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_lab/app.dart';
import 'package:flutter_lab/data/records.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

Map<String, Object?> _change(int day, int num, String type, String week, String subject, [List<Map<String, String>> fields = const []]) =>
    {'day': day, 'num': num, 'type': type, 'week': week, 'subject': subject, 'subgroup': 0, 'fields': fields};

String _history() => jsonEncode({
      'changes': [
        {
          'version': 1,
          'publishedAt': '2026-10-15T00:04:11.000Z',
          'diff': {
            'changes': [_change(1, 1, 'added', 'UPPER', 'Алгоритмы и структуры данных'), _change(1, 2, 'added', 'BOTH', 'Базы данных')],
          },
        },
        {
          'version': 2,
          'publishedAt': '2026-10-30T15:48:17.000Z',
          'diff': {
            'changes': [
              _change(1, 1, 'removed', 'LOWER', 'Алгоритмы и структуры данных'),
              _change(1, 2, 'changed', 'BOTH', 'Алгоритмы и структуры данных', [
                {'field': 'teachers', 'from': 'доц. Боднар А. В.', 'to': 'проф. Дмитрюк Т. Г.'},
              ]),
              _change(3, 3, 'changed', 'UPPER', 'Базы данных', [
                {'field': 'rooms', 'from': '8.705', 'to': '4.010'},
                {'field': 'kind', 'from': 'lecture', 'to': 'practice'},
              ]),
              _change(4, 2, 'added', 'BOTH', 'Профессионально-прикладная физическая подготовка'),
            ],
          },
        },
      ],
    });

void main() {
  final dir = Platform.environment['SHOT_DIR'];
  setUpAll(loadFonts);

  for (final dark in [false, true]) {
    final suffix = dark ? 'dark' : 'light';
    testWidgets('экран «Изменения»: версии островами, счётчики, дни, было/стало, $suffix', (tester) async {
      final key = GlobalKey();
      final records = MemoryRecords()..data['public:/groups/${Uri.encodeComponent('ПИ-25а')}/changes'] = _history();
      final c = await makeController(group: 'ПИ-25а', subgroup: 1, records: records, stored: {'preferences': '{"theme":"$suffix","onboarded":true}'});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(RepaintBoundary(key: key, child: App(controller: c)));
      await tester.pump();
      tester.state<NavigatorState>(find.byType(Navigator).first).pushNamed('/changes');
      await settleBounded(tester);
      await settleIsolates(tester);

      expect(find.text('30 октября, 18:48'), findsOneWidget);
      expect(find.text('15 октября, 03:04'), findsOneWidget);
      expect(find.textContaining('Версия'), findsNothing);
      expect(find.text('Первая публикация расписания'), findsOneWidget);
      expect(find.text('ПОНЕДЕЛЬНИК'), findsOneWidget);
      expect(find.text('Алгоритмы и структуры данных'), findsNWidgets(2));
      expect(find.textContaining('Дмитрюк Т. Г.'), findsOneWidget);
      expect(find.textContaining('4.010'), findsOneWidget);
      expect(find.textContaining('с 2 ноября'), findsWidgets);
      expect(find.text('Было'), findsNWidgets(3));
      expect(find.text('Стало'), findsNWidgets(3));
      expect(find.text('Вид занятия'), findsOneWidget);
      expect(find.text('Лекция'), findsOneWidget);
      expect(find.text('Практика'), findsOneWidget);
      expect(find.textContaining('lecture'), findsNothing);
      expect(find.textContaining('practice'), findsNothing);

      if (dir != null) {
        await tester.runAsync(() async {
          final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          File('$dir/changes_$suffix.png').writeAsBytesSync(data!.buffer.asUint8List());
        });
      }
      await unmount(tester);
    });
  }
}
