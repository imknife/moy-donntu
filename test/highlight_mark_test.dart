import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_lab/app.dart';
import 'package:flutter_lab/ui/highlight_mark.dart';
import 'package:flutter_lab/ui/motion.dart';
import 'package:flutter_lab/ui/theme.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contrast_test.dart' as contrast;
import 'support.dart';

Color over(Color fill, Color base) => Color.alphaBlend(fill, base);

Future<void> capture(WidgetTester tester, GlobalKey key, String path) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Widget specimen(Pal pal, HighlightStyle style) => Container(
      width: 420,
      color: pal.background,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(style.name, style: T.caption.copyWith(color: pal.muted)),
          const SizedBox(height: 10),
          HighlightMark(style: style, animate: false, child: Text('Сегодня', style: T.display.copyWith(color: pal.text))),
          const SizedBox(height: 14),
          HighlightMark(style: style, animate: false, child: Text('10:00–11:20', style: T.captionMedium.copyWith(color: pal.text))),
          const SizedBox(height: 14),
          Container(
            color: pal.tint,
            padding: const EdgeInsets.all(12),
            child: HighlightMark(style: style, animate: false, child: Text('Идёт сейчас', style: T.captionSemi.copyWith(color: pal.text))),
          ),
        ],
      ),
    );

void main() {
  final dir = Platform.environment['SHOT_DIR'];
  setUpAll(loadFonts);

  for (final pal in [Pal.light, Pal.darkPal]) {
    test('контраст текста на мазке не ниже 4.5: ${pal.dark ? 'тёмная' : 'светлая'}', () {
      for (final style in HighlightStyle.values) {
        final fill = highlightFill(pal, style);
        for (final base in [pal.background, pal.surface, pal.tint]) {
          expect(contrast.ratio(pal.text, over(fill, base)), greaterThanOrEqualTo(4.5), reason: '${style.name} на ${base.toARGB32().toRadixString(16)}');
        }
      }
    });
  }

  testWidgets('мазок не меняет размер и семантику текста', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(alignment: Alignment.topLeft, child: PalScope(pal: Pal.light, child: HighlightMark(padding: EdgeInsets.zero, child: Text('Сегодня', style: T.body)))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Сегодня'), findsOneWidget);
    expect(tester.getSize(find.byType(HighlightMark)), tester.getSize(find.text('Сегодня')));
    handle.dispose();
  });

  testWidgets('анимация появления отключается при меньше движения', (tester) async {
    Widget host(bool motion) => Directionality(
          textDirection: TextDirection.ltr,
          child: MotionScope(enabled: motion, child: PalScope(pal: Pal.light, child: HighlightMark(child: Text('Сегодня', style: T.body)))),
        );
    await tester.pumpWidget(host(false));
    expect(find.byType(Opacity), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(host(true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Opacity), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('обзор: мазков нет, время и статус обычным текстом', (tester) async {
    final c = await makeController(group: 'ПИ-25а', subgroup: 1, stored: {'preferences': '{"onboarded":true}'});
    await pumpApp(tester, c);
    final handle = tester.ensureSemantics();
    await tester.tap(find.bySemanticsLabel('Обзор'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Осталось'), findsOneWidget);
    expect(find.byType(HighlightMark), findsNothing);
    expect(find.text('Сегодня'), findsNothing);
    handle.dispose();
    await unmount(tester);
  });

  testWidgets('снимки мазка в PNG (только при SHOT_DIR)', (tester) async {
    if (dir == null) return;
    Directory(dir).createSync(recursive: true);
    final key = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(420, 900));
    for (final dark in [false, true]) {
      final theme = dark ? 'dark' : 'light';
      final pal = dark ? Pal.darkPal : Pal.light;
      for (final style in HighlightStyle.values) {
        final c = await makeController(group: 'ПИ-25а', subgroup: 1, stored: {'preferences': '{"theme":"$theme","onboarded":true}'});
        await tester.pumpWidget(RepaintBoundary(key: key, child: HighlightScope(style: style, child: App(controller: c))));
        await tester.pump();
        final handle = tester.ensureSemantics();
        await tester.tap(find.bySemanticsLabel('Обзор'));
        handle.dispose();
        await capture(tester, key, '$dir/overview-${style.name}-$theme.png');
        await tester.pumpWidget(const SizedBox());
      }
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: PalScope(
              pal: pal,
              child: Container(
                width: 420,
                color: pal.background,
                child: Column(mainAxisSize: MainAxisSize.min, children: [for (final s in HighlightStyle.values) specimen(pal, s)]),
              ),
            ),
          ),
        ),
      );
      await tester.binding.setSurfaceSize(const Size(420, 1000));
      await capture(tester, key, '$dir/specimen-$theme.png');
      await tester.pumpWidget(const SizedBox());
      await tester.binding.setSurfaceSize(const Size(420, 900));
    }
    await tester.binding.setSurfaceSize(null);
  });
}
