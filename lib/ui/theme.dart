import 'package:flutter/material.dart';

import 'type_settings.dart';

class Pal {
  const Pal({
    required this.dark,
    required this.background,
    required this.surface,
    required this.text,
    required this.muted,
    required this.link,
    required this.tint,
    required this.border,
    required this.axis,
    required this.soft,
    required this.segmentPill,
    required this.segmentOn,
    required this.segmentOnText,
    required this.danger,
    required this.changes,
    required this.onLink,
    required this.track,
    required this.hairline,
    required this.barIdle,
  });
  final bool dark;
  final Color background, surface, text, muted, link, tint, border, axis, soft, segmentPill, segmentOn, segmentOnText, danger, changes, onLink, track, hairline, barIdle;

  static const light = Pal(
    dark: false,
    background: Color(0xFFF2F3F5),
    surface: Color(0xFFFFFFFF),
    text: Color(0xFF101418),
    muted: Color(0xFF4B5A63),
    link: Color(0xFF006DB0),
    tint: Color(0xFFE3EFF8),
    border: Color(0xFFE6E7EA),
    axis: Color(0xFF848D94),
    soft: Color(0xFFF2F3F5),
    segmentPill: Color(0xFFFFFFFF),
    segmentOn: Color(0xFF101418),
    segmentOnText: Color(0xFFFFFFFF),
    danger: Color(0xFFBC0031),
    changes: Color(0xFFFCEBEE),
    onLink: Color(0xFFFFFFFF),
    track: Color(0xFFE4E5E8),
    hairline: Color(0xFFE3E3E6),
    barIdle: Color(0xFFC9C9CE),
  );

  static const darkPal = Pal(
    dark: true,
    background: Color(0xFF1F2732),
    surface: Color(0xFF26313F),
    text: Color(0xFFFFFFFF),
    muted: Color(0xFF8D97A1),
    link: Color(0xFF7EBBF9),
    tint: Color(0xFF2F3E54),
    border: Color(0xFF1F2732),
    axis: Color(0xFF8D97A1),
    soft: Color(0xFF2E3540),
    segmentPill: Color(0xFF26313F),
    segmentOn: Color(0xFF2F3E54),
    segmentOnText: Color(0xFF7EBBF9),
    danger: Color(0xFFF0777D),
    changes: Color(0xFF41202C),
    onLink: Color(0xFF0B1620),
    track: Color(0xFF2E3540),
    hairline: Color(0xFF2E3540),
    barIdle: Color(0xFF4D5764),
  );



  (Color, Color)? kindTone(String kind) {
    switch (kind) {
      case 'lecture':
        return dark ? (const Color(0xFF5FCF9A), const Color(0xFF1C3A2E)) : (const Color(0xFF137456), const Color(0xFFE5F3EC));
      case 'practice':
        return dark ? (const Color(0xFFF0B54A), const Color(0xFF3D3020)) : (const Color(0xFF8A5A00), const Color(0xFFFBF0DC));
      case 'lab':
        return dark ? (const Color(0xFFB39CFF), const Color(0xFF2F2A4A)) : (const Color(0xFF5B3FC4), const Color(0xFFEEEAFD));
    }
    return null;
  }
}

class PalScope extends InheritedWidget {
  const PalScope({super.key, required this.pal, required super.child});
  final Pal pal;

  static Pal of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<PalScope>()!.pal;

  @override
  bool updateShouldNotify(PalScope old) => old.pal != pal;
}

extension PalContext on BuildContext {
  Pal get pal => PalScope.of(this);
}

class T {
  static TextStyle get display => TextStyle(fontFamily: TypeSettings.family, fontWeight: FontWeight.w700, fontSize: 40, height: 44 / 40, fontFeatures: [FontFeature.tabularFigures()]);
  static TextStyle get title => TextStyle(fontFamily: TypeSettings.family, fontWeight: FontWeight.w500, fontSize: 30, height: 36 / 30, letterSpacing: -0.45, fontFeatures: [FontFeature.tabularFigures()]);
  static TextStyle get numeral => TextStyle(fontFamily: TypeSettings.family, fontWeight: FontWeight.w300, fontSize: 64, height: 1, letterSpacing: -2.56, fontFeatures: [FontFeature.tabularFigures()]);
  static TextStyle get sentence => TextStyle(fontFamily: TypeSettings.family, fontWeight: FontWeight.w300, fontSize: 24, height: 30 / 24);
  static TextStyle get sectionLabel => TextStyle(fontFamily: TypeSettings.family, fontWeight: FontWeight.w500, fontSize: 10.5, height: 14 / 10.5, letterSpacing: 0.63);
  static TextStyle get heading => TextStyle(fontFamily: TypeSettings.family, fontWeight: FontWeight.w600, fontSize: 18, height: 24 / 18);
  static TextStyle get body => TextStyle(fontFamily: TypeSettings.family, fontWeight: FontWeight.w400, fontSize: 14, height: 20 / 14);
  static TextStyle get caption => TextStyle(fontFamily: TypeSettings.family, fontWeight: FontWeight.w400, fontSize: 13, height: 18 / 13);
  static TextStyle get captionMedium => TextStyle(fontFamily: TypeSettings.family, fontWeight: FontWeight.w500, fontSize: 13, height: 18 / 13);
  static TextStyle get captionSemi => TextStyle(fontFamily: TypeSettings.family, fontWeight: FontWeight.w600, fontSize: 13, height: 18 / 13);
  static TextStyle get micro => TextStyle(fontFamily: TypeSettings.family, fontWeight: FontWeight.w400, fontSize: 12, height: 16 / 12);
  static TextStyle get microMedium => TextStyle(fontFamily: TypeSettings.family, fontWeight: FontWeight.w500, fontSize: 12, height: 16 / 12);
  static TextStyle get microSemi => TextStyle(fontFamily: TypeSettings.family, fontWeight: FontWeight.w600, fontSize: 12, height: 16 / 12);
  static TextStyle get overline => TextStyle(fontFamily: TypeSettings.family, fontWeight: FontWeight.w600, fontSize: 11, height: 14 / 11, letterSpacing: 0.4);
  static TextStyle get subject => TextStyle(fontFamily: TypeSettings.family, fontWeight: FontWeight.w500, fontSize: 15, height: 21 / 15);
  static TextStyle get dayNum => TextStyle(fontFamily: TypeSettings.family, fontWeight: FontWeight.w500, fontSize: 15, height: 1.3);
  static TextStyle get dayNumSel => TextStyle(fontFamily: TypeSettings.family, fontWeight: FontWeight.w700, fontSize: 15, height: 1.3);
  static TextStyle get lessonTitle => TextStyle(fontFamily: TypeSettings.family, fontWeight: FontWeight.w700, fontSize: 26, height: 32 / 26);
  static TextStyle get bodyLink => TextStyle(fontFamily: TypeSettings.family, fontWeight: FontWeight.w500, fontSize: 15, height: 20 / 15);
  static TextStyle get dayName => TextStyle(fontFamily: TypeSettings.family, fontWeight: FontWeight.w400, fontSize: 11, height: 15 / 11);
}
