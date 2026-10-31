import 'package:flutter/material.dart';

import 'icons.dart';
import 'motion.dart';
import 'theme.dart';
import 'derived.dart';
import 'type_settings.dart';

Future<R?> showAppSheet<R>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  String? subtitle,
  bool tall = false,
  bool scrollable = true,
}) {
  final c = context.pal;
  return showModalBottomSheet<R>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: c.background,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    clipBehavior: Clip.antiAlias,
    builder: (ctx) => AppSheet(title: title, subtitle: subtitle, tall: tall, scrollable: scrollable, child: Builder(builder: builder)),
  );
}

class AppSheet extends StatelessWidget {
  const AppSheet({super.key, required this.title, required this.child, this.subtitle, this.tall = false, this.scrollable = true});
  final String title;
  final String? subtitle;
  final Widget child;
  final bool tall;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final height = media.size.height - media.padding.top;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.title.copyWith(fontSize: 26, height: 32 / 26, color: c.text)),
                if (subtitle != null && subtitle!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.caption.copyWith(color: c.muted))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Tap(
            label: 'Закрыть',
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: AppIcon('close', size: 18, color: c.text),
            ),
          ),
        ],
      ),
    );
    final handle = Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 14),
        width: 40,
        height: 4,
        decoration: BoxDecoration(color: c.hairline, borderRadius: BorderRadius.circular(2)),
      ),
    );
    final body = scrollable
        ? Flexible(
            fit: tall ? FlexFit.tight : FlexFit.loose,
            child: SingleChildScrollView(padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + keyboard + media.padding.bottom), child: child),
          )
        : Flexible(fit: tall ? FlexFit.tight : FlexFit.loose, child: child);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height * 0.92, minHeight: tall ? height * 0.92 : 0),
      child: Column(mainAxisSize: MainAxisSize.min, children: [handle, header, body]),
    );
  }
}

class SheetGroup extends StatelessWidget {
  const SheetGroup({super.key, required this.children, this.label});
  final List<Widget> children;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: c.hairline));
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) Padding(padding: const EdgeInsets.fromLTRB(4, 12, 4, 8), child: Text(TypeSettings.caps(label!), style: T.sectionLabel.copyWith(color: c.muted))),
        Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
        ),
      ],
    );
  }
}

class SheetSwitchRow extends StatelessWidget {
  const SheetSwitchRow({super.key, required this.title, required this.detail, required this.value, required this.onChanged, this.icon});
  final String? icon;
  final String title;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Tap(
      label: title,
      onTap: () => onChanged(!value),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: c.background, borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: AppIcon(icon!, size: 20, color: c.text),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: T.subject.copyWith(fontSize: 16, height: 20 / 16, color: c.text)),
                    if (detail.isNotEmpty) Text(detail, style: T.caption.copyWith(height: 16 / 13, color: c.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SwitchPill(value: value),
            ],
          ),
        ),
      ),
    );
  }
}

class SwitchPill extends StatelessWidget {
  const SwitchPill({super.key, required this.value});
  final bool value;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final duration = context.motionEnabled ? const Duration(milliseconds: 220) : Duration.zero;
    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOutCubic,
      width: 48,
      height: 28,
      padding: const EdgeInsets.all(3),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(color: value ? c.link : c.track, borderRadius: BorderRadius.circular(14)),
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        width: 22,
        height: 22,
        decoration: BoxDecoration(color: value ? c.onLink : c.surface, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: value ? 0.18 : 0.1), blurRadius: 3, offset: const Offset(0, 1))]),
      ),
    );
  }
}

class SheetRow extends StatelessWidget {
  const SheetRow({super.key, required this.title, required this.onTap, this.detail, this.trailing});
  final String title;
  final String? detail;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Tap(
      label: title,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: T.subject.copyWith(fontSize: 16, height: 20 / 16, color: c.text)),
                    if (detail != null && detail!.isNotEmpty) Text(detail!, style: T.caption.copyWith(height: 16 / 13, color: c.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ?? AppIcon('chevron', size: 16, color: c.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class SheetChip extends StatelessWidget {
  const SheetChip({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Tap(
      label: label,
      onTap: onTap,
      child: AnimatedContainer(
        duration: context.motionEnabled ? const Duration(milliseconds: 180) : Duration.zero,
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: selected ? c.segmentOn : c.surface, borderRadius: BorderRadius.circular(20)),
        child: AnimatedDefaultTextStyle(
          duration: context.motionEnabled ? const Duration(milliseconds: 180) : Duration.zero,
          style: T.captionSemi.copyWith(color: selected ? c.segmentOnText : c.text),
          child: Text(label),
        ),
      ),
    );
  }
}

class SheetButton extends StatelessWidget {
  const SheetButton({super.key, required this.label, required this.onTap, this.enabled = true});
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Tap(
      label: label,
      onTap: enabled ? onTap : () {},
      child: Container(
        height: 52,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: enabled ? c.segmentOn : c.track, borderRadius: BorderRadius.circular(26)),
        child: Text(label.cased, style: T.subject.copyWith(color: enabled ? c.segmentOnText : c.muted)),
      ),
    );
  }
}

class SheetLabel extends StatelessWidget {
  const SheetLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
        child: Text(TypeSettings.caps(text), style: T.sectionLabel.copyWith(color: context.pal.muted)),
      );
}

Future<int?> showChoiceSheet(BuildContext context, {required String title, required List<String> options, required int selected, List<String>? details}) {
  return showAppSheet<int>(
    context,
    title: title,
    builder: (ctx) {
      final c = ctx.pal;
      return SheetGroup(children: [
        for (var i = 0; i < options.length; i++)
          SheetRow(
            title: options[i],
            detail: details == null ? null : details[i],
            onTap: () => Navigator.of(ctx).pop(i),
            trailing: i == selected ? AppIcon('check', size: 20, color: c.link) : const SizedBox(width: 20),
          ),
      ]);
    },
  );
}

class SelectorPill extends StatelessWidget {
  const SelectorPill({super.key, required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Tap(
      label: '$label: $value',
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.fromLTRB(14, 0, 10, 0),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.captionSemi.copyWith(color: c.text))),
            const SizedBox(width: 4),
            AppIcon('chevronDown', size: 16, color: c.muted),
          ],
        ),
      ),
    );
  }
}
