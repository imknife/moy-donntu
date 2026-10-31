import 'package:flutter/material.dart';

import 'derived.dart';
import 'icons.dart';
import 'theme.dart';
import 'type_settings.dart';
import 'widgets.dart';

extension GroupedPalette on Pal {
  Color get pageGray => background;
  Color get island => surface;
}

const double groupRadius = 16;
const double groupGap = 8;
const double groupedSide = 16;
const double _iconBox = 32;
const double _rowSide = 16;
const double _iconInset = _rowSide + _iconBox + 12;

class GroupedBackground extends StatelessWidget {
  const GroupedBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(color: context.pal.pageGray, child: SizedBox.expand(child: child));
}

class GroupedPage extends StatelessWidget {
  const GroupedPage({super.key, required this.title, required this.children, this.actions = const [], this.bottom = 24});
  final String title;
  final List<Widget> children;
  final List<Widget> actions;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Scaffold(
      backgroundColor: c.pageGray,
      body: SafeArea(
        child: Column(
          children: [
            BackBar(title: title, actions: actions),
            Expanded(child: ListView(padding: EdgeInsets.fromLTRB(groupedSide, 4, groupedSide, bottom), children: children)),
          ],
        ),
      ),
    );
  }
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children, this.title, this.top = groupGap});
  final List<Widget> children;
  final String? title;
  final double top;

  double _inset(Widget child) => child is SettingsRow && child.icon != null ? _iconInset : _rowSide;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(Divider(height: 1, thickness: 1, indent: _inset(children[i]), color: c.hairline));
      items.add(children[i]);
    }
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) Padding(padding: const EdgeInsets.fromLTRB(_rowSide, 4, _rowSide, 8), child: Text(TypeSettings.caps(title!), style: T.sectionLabel.copyWith(color: c.muted))),
          Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: c.island, borderRadius: BorderRadius.circular(groupRadius)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items),
          ),
        ],
      ),
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({super.key, required this.title, this.icon, this.detail, this.onTap, this.trailing, this.selected = false});
  final String title;
  final String? icon;
  final String? detail;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final end = trailing ?? (selected ? AppIcon('check', size: 20, color: c.link) : (onTap != null ? AppIcon('chevron', size: 18, color: c.muted) : null));
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _rowSide, vertical: 6),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: _iconBox,
                height: _iconBox,
                decoration: BoxDecoration(color: c.background, borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: AppIcon(icon!, size: 18, color: c.text),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: T.subject.copyWith(color: c.text)),
                  if (detail != null) Text(detail!, style: T.micro.copyWith(color: c.muted)),
                ],
              ),
            ),
            if (end != null) ...[const SizedBox(width: 8), end],
          ],
        ),
      ),
    );
    return onTap == null ? row : Tap(onTap: onTap!, child: row);
  }
}

class SettingsToggle extends StatelessWidget {
  const SettingsToggle({super.key, required this.title, required this.value, required this.onChanged, this.detail});
  final String title;
  final String? detail;
  final bool value;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return SettingsRow(
      title: title,
      detail: detail,
      trailing: Semantics(
        label: title,
        child: Switch(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          activeThumbColor: Colors.white,
          activeTrackColor: c.link,
          inactiveThumbColor: c.dark ? c.muted : Colors.white,
          inactiveTrackColor: c.dark ? c.soft : c.axis,
          trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
    );
  }
}
