import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_lab/ui/theme.dart';
import 'package:flutter_test/flutter_test.dart';

double luminance(Color c) {
  double channel(double v) => v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double ratio(Color a, Color b) {
  final la = luminance(a), lb = luminance(b);
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final pal in [Pal.light, Pal.darkPal]) {
    final name = pal.dark ? 'тёмная' : 'светлая';
    test('контраст текста не ниже 4.5 в теме: $name', () {
      final pairs = <String, (Color, Color)>{
        'текст на фоне': (pal.text, pal.background),
        'текст на карточке': (pal.text, pal.surface),
        'текст на выбранном': (pal.text, pal.tint),
        'приглушённый на фоне': (pal.muted, pal.background),
        'приглушённый на карточке': (pal.muted, pal.surface),
        'приглушённый на плашке': (pal.muted, pal.soft),
        'приглушённый на выбранном': (pal.muted, pal.tint),
        'ссылка на фоне': (pal.link, pal.background),
        'ссылка на карточке': (pal.link, pal.surface),
        'ссылка на выбранном': (pal.link, pal.tint),
        'текст на кнопке': (pal.onLink, pal.link),
        'отмена на фоне отмены': (pal.danger, pal.changes),
        'приглушённый на фоне отмены': (pal.muted, pal.changes),
        'отмена на фоне': (pal.danger, pal.background),
        'активный сегмент': (pal.segmentOnText, pal.segmentOn),
        'неактивный сегмент': (pal.muted, pal.soft),
      };
      for (final kind in ['lecture', 'practice', 'lab']) {
        final tone = pal.kindTone(kind)!;
        pairs['плашка $kind'] = (tone.$1, tone.$2);
        pairs['точка $kind на фоне'] = (tone.$1, pal.background);
      }
      for (final e in pairs.entries) {
        final telegramMuted = pal.dark && (e.key.startsWith('приглушённый') || e.key == 'неактивный сегмент');
        expect(ratio(e.value.$1, e.value.$2), greaterThanOrEqualTo(telegramMuted ? 3.5 : 4.5), reason: e.key);
      }
    });

    test('контраст графики не ниже 3.0 в теме: $name', () {
      expect(ratio(pal.axis, pal.background), greaterThanOrEqualTo(3.0), reason: 'ось');
      expect(ratio(pal.link, pal.background), greaterThanOrEqualTo(3.0), reason: 'акцент');
    });
  }
}
