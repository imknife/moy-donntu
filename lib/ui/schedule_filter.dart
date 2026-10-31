import 'package:flutter/material.dart';

import '../data/app_controller.dart';
import '../data/store.dart';
import '../domain/schedule.dart';
import 'sheet.dart';
import 'scope.dart';

const filterKinds = ['lecture', 'practice', 'lab', 'exam', 'credit', 'consultation', 'coursework'];

Future<void> showScheduleFilter(BuildContext context, AppController controller) {
  final store = controller.store;
  return showAppSheet<void>(
    context,
    title: 'Показывать',
    builder: (ctx) => ValueListenableBuilder<Prefs>(
      valueListenable: store.prefs,
      builder: (ctx, prefs, _) {
        final hidden = prefs.hiddenKinds.toSet();
        void toggleKind(String kind) {
          final next = {...hidden};
          if (!next.remove(kind)) next.add(kind);
          store.setPrefs((p) => p.copyWith(hiddenKinds: next.toList()));
        }

        void go(String route) {
          Navigator.of(ctx).pop();
          context.open(route);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SheetGroup(children: [
              SheetSwitchRow(title: 'Прошедшие пары', detail: 'Показывать серым', value: !prefs.hidePast, onChanged: (v) => store.setPrefs((p) => p.copyWith(hidePast: !v))),
              SheetSwitchRow(title: 'Отменённые', detail: 'Показывать зачёркнутыми', value: prefs.showCancelled, onChanged: (v) => store.setPrefs((p) => p.copyWith(showCancelled: v))),
              SheetSwitchRow(title: 'Окна', detail: 'Перерывы между парами', value: prefs.showGaps, onChanged: (v) => store.setPrefs((p) => p.copyWith(showGaps: v))),
            ]),
            SheetLabel(prefs.hiddenKinds.isEmpty ? 'Типы пар' : 'Типы пар · скрыто ${prefs.hiddenKinds.length}'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kind in filterKinds) SheetChip(label: kindLabel[kind] ?? kind, selected: !hidden.contains(kind), onTap: () => toggleKind(kind)),
              ],
            ),
            SheetGroup(label: 'Расписание', children: [
              SheetRow(title: 'Экспорт в календарь', detail: 'Файл .ics для любого календаря', onTap: () => go('calendar')),
              SheetRow(title: 'Изменения в расписании', detail: 'Что поменялось в вашей группе', onTap: () => go('changes')),
              SheetRow(title: 'Звонки', detail: 'Время начала и конца пар', onTap: () => go('bells')),
            ]),
          ],
        );
      },
    ),
  );
}
