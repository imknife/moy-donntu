import 'package:flutter/material.dart';

import '../domain/time_utils.dart';
import 'derived.dart';
import 'icons.dart';
import 'motion.dart';
import 'theme.dart';
import 'widgets.dart' show scaled;

const modeKinds = ['День', 'Неделя', 'Месяц'];

typedef PeriodLines = ({String first, String second, String label});

PeriodLines periodLines(DateTime selected, int mode) {
  if (mode == 2) {
    final month = monthsNominative[selected.month - 1];
    return (first: month, second: '${selected.year}', label: '$month ${selected.year}, месяц');
  }
  final monday = startOfIsoWeek(selected);
  final sunday = addDays(monday, 6);
  final sameMonth = monday.month == sunday.month;
  final first = sameMonth ? '${monday.day} –' : '${monday.day} ${monthsShort[monday.month - 1]} –';
  final second = '${sunday.day} ${monthsGenitive[sunday.month - 1]}';
  return (first: first, second: second, label: '$first $second, неделя');
}

String periodOneLine(DateTime selected, int mode) {
  if (mode == 2) return '${monthsNominative[selected.month - 1]} ${selected.year}';
  final monday = startOfIsoWeek(selected);
  final sunday = addDays(monday, 6);
  final end = '${sunday.day} ${monthsShort[sunday.month - 1]}';
  if (monday.month == sunday.month) return '${monday.day} – $end';
  return '${monday.day} ${monthsShort[monday.month - 1]} – $end';
}

class ModeSwitch extends StatelessWidget {
  const ModeSwitch({super.key, required this.value, required this.onChanged, this.compact = false});
  final int value;
  final void Function(int index) onChanged;
  final bool compact;

  double _textWidth(BuildContext context, String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: T.body.copyWith(fontWeight: FontWeight.w600, height: 18 / 14)),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return painter.width.ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final duration = context.motionEnabled ? const Duration(milliseconds: 220) : Duration.zero;
    final height = scaled(context, 34);
    final pad = compact ? 6.0 : 10.0;
    const radius = 6.0;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.track, borderRadius: BorderRadius.circular(8)),
      child: LayoutBuilder(
        builder: (context, box) {
          final count = modeKinds.length;
          final widths = [for (final k in modeKinds) _textWidth(context, k) + 2 * pad];
          var left = 0.0;
          for (var i = 0; i < value; i++) {
            left += widths[i] + 2;
          }
          return Stack(
            children: [
              AnimatedPositioned(
                duration: duration,
                curve: Curves.easeOutCubic,
                left: left,
                top: 0,
                width: widths[value],
                height: height,
                child: DecoratedBox(decoration: BoxDecoration(color: c.segmentOn, borderRadius: BorderRadius.circular(radius))),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < count; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    _segment(context, c, i, widths[i], height, duration),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _segment(BuildContext context, Pal c, int i, double width, double height, Duration duration) {
    final selected = i == value;
    return Tap(
      label: modeKinds[i],
      onTap: () => onChanged(i),
      child: SizedBox(
        width: width,
        height: height,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: duration,
            style: T.body.copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w500, height: 18 / 14, color: selected ? c.segmentOnText : c.muted),
            child: Text(modeKinds[i], maxLines: 1, softWrap: false),
          ),
        ),
      ),
    );
  }
}

class PeriodNav extends StatelessWidget {
  const PeriodNav({
    super.key,
    required this.selected,
    required this.mode,
    required this.onStep,
    this.compact = false,
  });
  final ValueNotifier<DateTime> selected;
  final ValueNotifier<int> mode;
  final void Function(int step) onStep;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    Widget arrow(int step) => Tap(
          label: step > 0 ? 'Следующий период' : 'Предыдущий период',
          onTap: () => onStep(step),
          child: SizedBox(
            width: compact ? 32 : 36,
            height: 40,
            child: Center(child: AppIcon(step > 0 ? 'chevron' : 'chevronLeft', size: 22, color: c.text)),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        arrow(-1),
        Flexible(
          child: Derived<PeriodLines>(
            listenable: Listenable.merge([selected, mode]),
            read: () => periodLines(selected.value, mode.value),
            builder: (context, lines) => Semantics(
              label: lines.label,
              excludeSemantics: true,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(periodOneLine(selected.value, mode.value), maxLines: 1, softWrap: false, textAlign: TextAlign.center, style: T.captionMedium.copyWith(height: 16 / 13, color: c.muted)),
              ),
            ),
          ),
        ),
        arrow(1),
      ],
    );
  }
}
