import 'package:flutter/material.dart';
import 'package:flutter_lab/app.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  setUpAll(loadFonts);

  for (final entry in {360.0: 1, 320.0: 2}.entries) {
    testWidgets('строка пары: «Дискретная математика» занимает не больше ${entry.value} строк на ${entry.key.toInt()}', (tester) async {
      final c = await makeController(
        group: 'ПИ-25а',
        subgroup: 1,
        now: DateTime.utc(2026, 10, 28, 5),
        stored: {'preferences': '{"theme":"light","onboarded":true}'},
      );
      await tester.binding.setSurfaceSize(Size(entry.key, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(App(controller: c));
      await tester.pump();
      await tester.pumpAndSettle();
      final titles = find.text('Дискретная математика');
      expect(titles, findsWidgets);
      for (final element in titles.evaluate()) {
        final box = element.renderObject! as RenderBox;
        expect(box.size.height, lessThanOrEqualTo(21.5 * entry.value), reason: 'высота названия ${box.size.height}');
      }
      expect(find.textContaining('ауд.'), findsNothing);
      await unmount(tester);
    });
  }
}
