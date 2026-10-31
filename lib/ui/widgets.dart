import 'package:flutter/material.dart';

import 'derived.dart';
import 'icons.dart';
import 'motion.dart';
import 'theme.dart';
import 'type_settings.dart';

class SegmentedPill extends StatelessWidget {
  const SegmentedPill({super.key, required this.options, required this.value, required this.onChanged, this.height = 30});
  final List<String> options;
  final int value;
  final void Function(int index) onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final duration = context.motionEnabled ? const Duration(milliseconds: 220) : Duration.zero;
    final count = options.length;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.track, borderRadius: BorderRadius.circular(8)),
      child: LayoutBuilder(
        builder: (context, box) {
          final cell = (box.maxWidth - 2 * (count - 1)) / count;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: duration,
                curve: Curves.easeOutCubic,
                left: value * (cell + 2),
                top: 0,
                width: cell,
                height: height,
                child: DecoratedBox(decoration: BoxDecoration(color: c.segmentOn, borderRadius: BorderRadius.circular(6))),
              ),
              Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  for (var i = 0; i < count; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    _segment(context, c, i, duration),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _segment(BuildContext context, Pal c, int i, Duration duration) {
    final selected = i == value;
    final cell = Tap(
      label: options[i],
      onTap: () => onChanged(i),
      child: SizedBox(
        height: height,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: AnimatedDefaultTextStyle(
                duration: duration,
                style: (selected ? T.captionSemi : T.captionMedium).copyWith(color: selected ? c.segmentOnText : c.muted),
                child: Text(options[i].cased),
              ),
            ),
          ),
        ),
      ),
    );
    return Expanded(child: cell);
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(TypeSettings.caps(text), style: T.sectionLabel.copyWith(color: context.pal.muted)),
      );
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.color, this.padding = const EdgeInsets.all(12), this.onTap});
  final Widget child;
  final Color? color;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(color: color ?? c.surface, borderRadius: BorderRadius.circular(16)),
      child: child,
    );
    return onTap == null ? box : Tap(onTap: onTap!, child: box);
  }
}

class MenuRow extends StatelessWidget {
  const MenuRow({super.key, required this.icon, required this.title, this.detail, this.onTap, this.trailing, this.enabled = true});
  final String icon;
  final String title;
  final String? detail;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: c.background, borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: AppIcon(icon, size: 20, color: c.text),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.cased, style: T.subject.copyWith(color: c.text)),
                  if (detail != null) Text(detail!.cased, style: T.micro.copyWith(color: c.muted)),
                ],
              ),
            ),
            if (trailing != null) trailing! else if (onTap != null) AppIcon('chevron', size: 18, color: c.muted),
          ],
        ),
      ),
    );
    if (onTap == null || !enabled) return row;
    return Tap(onTap: onTap!, child: row);
  }
}

class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.text, {super.key, this.horizontal = 16});
  final String text;
  final double horizontal;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 8),
        child: Text(text.cased, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.title.copyWith(color: context.pal.text)),
      );
}

class BackBar extends StatelessWidget {
  const BackBar({super.key, required this.title, this.actions = const []});
  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Tap(
            label: 'Назад',
            onTap: () => Navigator.of(context).maybePop(),
            child: SizedBox(width: 56, height: 56, child: Center(child: AppIcon('back', size: 22, color: c.text))),
          ),
          Expanded(child: Text(title.cased, style: T.heading.copyWith(color: c.text))),
          ...actions,
        ],
      ),
    );
  }
}

double scaled(BuildContext context, double value) => value * (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 2.2);
