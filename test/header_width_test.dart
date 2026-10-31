import 'package:flutter/material.dart';
import 'package:flutter_lab/app.dart';
import 'package:flutter_lab/ui/schedule_header_parts.dart';
import 'package:flutter_lab/ui/theme.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

const sizes = [Size(320, 640), Size(360, 740)];
const scales = [1.0, 1.5];

Future<List<String>> pumpAndCollect(WidgetTester tester, Size size, double scale, Future<void> Function() body) async {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (d) => errors.add(d.exceptionAsString().split('\n').first);
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return errors;
}

void expectInside(WidgetTester tester, Finder finder, Size size, String what) {
  expect(finder, findsWidgets, reason: what);
  final rect = tester.getRect(finder.first);
  expect(rect.left, greaterThanOrEqualTo(-0.5), reason: '$what слева: $rect');
  expect(rect.right, lessThanOrEqualTo(size.width + 0.5), reason: '$what справа: $rect');
}

void main() {
  setUpAll(loadFonts);

  test('подпись периода: неделя в одном и в разных месяцах, месяц', () {
    expect(periodLines(DateTime.utc(2026, 10, 22), 0), (first: '19 –', second: '25 октября', label: '19 – 25 октября, неделя'));
    expect(periodLines(DateTime.utc(2026, 10, 29), 1), (first: '26 окт –', second: '1 ноября', label: '26 окт – 1 ноября, неделя'));
    expect(periodLines(DateTime.utc(2026, 10, 22), 2), (first: 'Октябрь', second: '2026', label: 'Октябрь 2026, месяц'));
    expect(periodLines(DateTime.utc(2026, 9, 5), 2), (first: 'Сентябрь', second: '2026', label: 'Сентябрь 2026, месяц'));
  });

  test('период в одну строку с сокращённым месяцем', () {
    expect(periodOneLine(DateTime.utc(2026, 10, 22), 0), '19 – 25 окт');
    expect(periodOneLine(DateTime.utc(2026, 10, 29), 1), '26 окт – 1 ноя');
    expect(periodOneLine(DateTime.utc(2026, 12, 30), 1), '28 дек – 3 янв');
    expect(periodOneLine(DateTime.utc(2026, 10, 22), 2), 'Октябрь 2026');
  });

  for (final size in sizes) {
    for (final scale in scales) {
      for (final theme in ['light', 'dark']) {
        testWidgets('шапка ${size.width.toInt()} px ×$scale $theme: ничего не вылезает', (tester) async {
          final c = await makeController(
            group: 'ПИ-25а',
            subgroup: 1,
            now: DateTime.utc(2026, 10, 29, 7),
            stored: {'preferences': '{"theme":"$theme","onboarded":true}'},
          );
          final handle = tester.ensureSemantics();
          final errors = await pumpAndCollect(tester, size, scale, () async {
            await tester.pumpWidget(App(controller: c));
            await tester.pump();
            await tester.pumpAndSettle();
            await tester.tap(find.text('Неделя'));
            await tester.pumpAndSettle();
            expect(find.text('26 окт – 1 ноя'), findsOneWidget);
            expectInside(tester, find.text('26 окт – 1 ноя'), size, 'период');
            final period = tester.getRect(find.text('26 окт – 1 ноя'));
            final modeSwitch = tester.getRect(find.text('Месяц'));
            expect(period.left >= modeSwitch.right - 0.5 || period.top >= modeSwitch.bottom - 0.5, isTrue, reason: 'период правее или ниже переключателя');
            expectInside(tester, find.text('День'), size, 'сегмент День');
            expectInside(tester, find.text('Месяц'), size, 'сегмент Месяц');
            expectInside(tester, find.text('ПИ-25а · 1 п/г'), size, 'кнопка группы');
            await tester.tap(find.text('День'));
            await tester.pumpAndSettle();
            expectInside(tester, find.textContaining('· верхняя'), size, 'строка дня');
            final dayLine = tester.getRect(find.textContaining('· верхняя'));
            final groupLine = tester.getRect(find.text('ПИ-25а · 1 п/г'));
            expect(dayLine.right, lessThanOrEqualTo(groupLine.left + 0.5), reason: 'день и неделя левее группы');
            expect((dayLine.center.dy - groupLine.center.dy).abs(), lessThan(4), reason: 'одна строка');
            await tester.tap(find.text('Месяц'));
            await tester.pumpAndSettle();
            expect(find.text('Октябрь 2026'), findsOneWidget);
            expectInside(tester, find.text('Октябрь 2026'), size, 'название месяца');
            await tester.tap(find.bySemanticsLabel('Следующий период'));
            await tester.pumpAndSettle();
            expect(find.text('Ноябрь 2026'), findsOneWidget);
            expectInside(tester, find.text('Сегодня'), size, 'кнопка Сегодня');
            await tester.tap(find.text('День'));
            await tester.pumpAndSettle();
            expectInside(tester, find.text('Сегодня'), size, 'кнопка Сегодня в дне');
            expect(tester.getRect(find.text('Сегодня')).top, greaterThan(tester.getRect(find.text('ПИ-25а · 1 п/г')).bottom), reason: 'Сегодня всплывает под шапкой, а не в ней');
            expectInside(tester, find.textContaining('· верхняя').evaluate().isNotEmpty ? find.textContaining('· верхняя') : find.textContaining('· нижняя'), size, 'строка дня при смещении');
            await unmount(tester);
          });
          handle.dispose();
          expect(errors, isEmpty);
        });
      }
    }
  }

  for (final dark in [false, true]) {
    testWidgets('переключатель ${dark ? 'тёмная' : 'светлая'}: активный сегмент контрастный', (tester) async {
      final pal = dark ? Pal.darkPal : Pal.light;
      var picked = -1;
      await tester.pumpWidget(
        PalScope(
          pal: pal,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: ModeSwitch(value: 1, onChanged: (i) => picked = i)),
          ),
        ),
      );
      AnimatedDefaultTextStyle styleOf(String label) => tester.widget<AnimatedDefaultTextStyle>(find.ancestor(of: find.text(label), matching: find.byType(AnimatedDefaultTextStyle)).first);
      final thumb = tester.widget<DecoratedBox>(find.descendant(of: find.byType(AnimatedPositioned), matching: find.byType(DecoratedBox)));
      expect((thumb.decoration as BoxDecoration).color, pal.segmentOn);
      expect(styleOf('Неделя').style.color, pal.segmentOnText);
      expect(styleOf('День').style.color, pal.muted);
      await tester.tap(find.text('Месяц'));
      expect(picked, 2);
    });
  }
}
