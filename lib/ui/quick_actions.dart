import 'package:flutter/material.dart';

import '../domain/brand.dart';
import 'derived.dart';
import 'icons.dart';
import 'scope.dart';
import 'services.dart';
import 'sheet.dart';
import 'theme.dart';
import 'type_settings.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.pal;
    return Derived<int>(
      listenable: Listenable.merge([app.store.prefs, app.features]),
      read: () => Object.hash(app.store.prefs.value.quickServices.join(','), app.features.value),
      builder: (context, _) {
        final picked = app.store.prefs.value.quickServices;
        final features = app.features.value;
        final shown = [
          for (final route in picked)
            for (final s in services)
              if (s.route == route && serviceVisible(s.route, features)) s,
        ];
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
          child: shown.isEmpty
              ? Tap(
                  label: 'Выбрать быстрые действия',
                  onTap: () => showQuickEditor(context),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
                    child: Text('Выбрать быстрые действия'.cased, style: T.captionSemi.copyWith(color: c.link)),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < shown.length; i += 4)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var k = 0; k < 4; k++) Expanded(child: i + k < shown.length ? _Tile(service: shown[i + k]) : const SizedBox.shrink()),
                        ],
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.service});
  final Service service;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Tap(
      label: service.name,
      onTap: () => context.open(service.route),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: c.background, borderRadius: BorderRadius.circular(14)),
              alignment: Alignment.center,
              child: AppIcon(service.icon, size: 22, color: c.text),
            ),
            const SizedBox(height: 6),
            for (final word in service.name.split(' '))
              SizedBox(width: double.infinity, child: FittedBox(fit: BoxFit.scaleDown, child: Text(word, maxLines: 1, style: T.micro.copyWith(color: c.text, fontSize: 11, height: 14 / 11)))),
          ],
        ),
      ),
    );
  }
}

Future<void> showQuickEditor(BuildContext context) {
  final app = context.app;
  return showAppSheet<void>(
    context,
    title: 'Быстрые действия',
    builder: (ctx) => ValueListenableBuilder(
      valueListenable: app.store.prefs,
      builder: (ctx, prefs, _) {
        final features = app.features.value;
        return SheetGroup(children: [
          for (final s in services)
            if (serviceVisible(s.route, features))
              SheetSwitchRow(
                icon: s.icon,
                title: s.name,
                detail: '',
                value: prefs.quickServices.contains(s.route),
                onChanged: (v) => app.store.setPrefs((p) => p.copyWith(quickServices: v ? [...p.quickServices, s.route] : [for (final r in p.quickServices) if (r != s.route) r])),
              ),
        ]);
      },
    ),
  );
}
