import 'package:flutter/material.dart';
import 'package:flutter_lab/data/store.dart';
import 'package:flutter_lab/ui/icons.dart';
import 'package:flutter_lab/ui/theme.dart';
import 'package:flutter_lab/ui/type_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  setUpAll(loadFonts);

  test('регистр текста не меняется, заглавные для подписей сохраняются', () {
    expect(TypeSettings.cased('Расписание · ПИ-25а'), 'Расписание · ПИ-25а');
    expect('Расписание пар ДонНТУ'.cased, 'Расписание пар ДонНТУ');
    expect(TypeSettings.caps('Лекция'), 'ЛЕКЦИЯ');
  });

  test('шрифт всегда Onest во всех стилях', () {
    expect(TypeSettings.family, 'Onest');
    expect(T.body.fontFamily, 'Onest');
    expect(T.heading.fontFamily, 'Onest');
    expect(T.lessonTitle.fontFamily, 'Onest');
  });

  test('старые ключи шрифта, значков, движения и регистра игнорируются при чтении и не пишутся обратно', () {
    final prefs = Prefs.fromJson({'theme': 'dark', 'fontSize': 'large'});
    final old = Prefs.fromJson({...prefs.toJson(), 'font': 'jost', 'iconSet': 'phosphor', 'motion': 'reduced', 'textCase': 'lower'});
    expect(old, prefs);
    expect(old.theme, ThemeChoice.dark);
    expect(old.largeText, isTrue);
    for (final key in ['font', 'iconSet', 'motion', 'textCase']) {
      expect(old.toJson().containsKey(key), isFalse, reason: key);
    }
  });

  testWidgets('значки рисуются, неизвестное имя даёт запасной', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Row(children: [
        for (final n in ['home', 'schedule', 'clock', 'trash', 'filter', 'deadline', 'no-such']) AppIcon(n, color: Colors.black),
      ]),
    ));
    expect(tester.takeException(), isNull);
  });
}
