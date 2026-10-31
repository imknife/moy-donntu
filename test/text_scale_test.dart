import 'package:flutter/material.dart';
import 'package:flutter_lab/domain/brand.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

const routes = [
  '/lesson?date=2026-10-23&group=ПИ-25а&sub=1&slot=2&key=2-0-Алгоритмы и структуры данных',
  '/groups',
  '/notes',
  '/note',
  '/settings',
  '/appearance',
  '/about',
  '/links',
  '/search',
  '/bells',
  '/academic',
  '/edit-profile',
  '/feedback',
  '/calendar',
  '/start-screen',
  '/privacy',
  '/changes',
  '/notification-settings',
  '/teachers',
  '/rooms',
  '/room?room=8.705&date=2026-10-23',
  '/group?group=ПИ-25б',
  '/login',
  '/materials',
  '/gradebook',
  '/student-card',
  '/cabinet',
  '/logout',
  '/campus?from=4&to=1',
];

Future<List<String>> collectErrors(WidgetTester tester, double scale, Future<void> Function() body) async {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (d) => errors.add('${d.exceptionAsString().split('\n').first} ${d.toDiagnosticsNode().toStringDeep().split('\n').where((l) => l.contains('flutter_lab/lib')).take(2).join(' ')}');
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return errors.toSet().toList();
}

void main() {
  setUpAll(loadFonts);

  for (final scale in [1.5, 2.0]) {
    testWidgets('×$scale: вкладки и режимы расписания', (tester) async {
      final c = await makeController(group: 'ПИ-25а', subgroup: 1);
      final errors = await collectErrors(tester, scale, () async {
        await pumpApp(tester, c);
        for (var tab = 0; tab < 4; tab++) {
          c.tab.value = tab;
          await settleBounded(tester);
        }
        c.tab.value = 1;
        await settleBounded(tester);
        for (final mode in ['Неделя', 'Месяц', 'День']) {
          await tester.tap(find.text(mode));
          await settleBounded(tester);
        }
        await unmount(tester);
      });
      expect(errors, isEmpty);
    });

    for (final route in routes) {
      testWidgets('×$scale: $route', (tester) async {
        final c = await makeController(group: 'ПИ-25а', subgroup: 1);
        c.features.value = const Features(campus: true);
        final errors = await collectErrors(tester, scale, () async {
          await pumpApp(tester, c);
          tester.state<NavigatorState>(find.byType(Navigator).first).pushNamed(route);
          await settleBounded(tester);
          await settleIsolates(tester);
          await unmount(tester);
        });
        expect(errors, isEmpty);
      });
    }
  }
}
