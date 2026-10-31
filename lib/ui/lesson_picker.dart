import 'package:flutter/material.dart';

import '../data/app_controller.dart';
import '../domain/schedule.dart';
import '../domain/time_utils.dart';
import 'derived.dart';
import 'sheet.dart';
import 'theme.dart';
import 'type_settings.dart';

typedef LessonRef = ({String key, String date, String subject, String kind});

Future<LessonRef?> pickLesson(BuildContext context, AppController controller, {int days = 14}) {
  return showAppSheet<LessonRef>(
    context,
    title: 'К какой паре',
    subtitle: 'Ближайшие $days дней вашего расписания',
    tall: true,
    builder: (ctx) {
      final model = controller.model.value;
      final today = controller.clock.value.today;
      if (model == null) return Padding(padding: const EdgeInsets.all(16), child: Text('Расписание не загружено'.cased, style: T.body.copyWith(color: ctx.pal.muted)));
      final blocks = <Widget>[];
      for (var i = 0; i < days; i++) {
        final day = addDays(today, i);
        final seen = <int>{};
        final items = [
          for (final it in model.items(day))
            if (seen.add(it.num)) it,
        ];
        if (items.isEmpty) continue;
        blocks.add(
          SheetGroup(
            label: '${dayNames[isoDay(day)]}, ${formatDayDate(day)}',
            children: [
              for (final it in items)
                SheetRow(
                  title: it.lesson.subject,
                  detail: '${shortTime(it.bell.start)}–${shortTime(it.bell.end)} · ${kindLabel[it.lesson.kind] ?? ''}',
                  trailing: const SizedBox.shrink(),
                  onTap: () => Navigator.of(ctx).pop((key: it.key, date: ymd(day), subject: it.lesson.subject, kind: it.lesson.kind)),
                ),
            ],
          ),
        );
      }
      if (blocks.isEmpty) return Padding(padding: const EdgeInsets.all(16), child: Text('В ближайшие дни пар нет'.cased, style: T.body.copyWith(color: ctx.pal.muted)));
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: blocks);
    },
  );
}

class LessonAttachRow extends StatelessWidget {
  const LessonAttachRow({super.key, required this.subject, required this.date, required this.onPick, required this.onClear});
  final String? subject;
  final String? date;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final attached = subject != null && subject!.isNotEmpty;
    final day = date == null ? null : parseYmd(date!);
    final detail = attached ? [subject!, if (day != null) formatDayDate(day)].join(' · ') : 'Не привязано';
    return SheetRow(
      title: 'Пара',
      detail: detail,
      onTap: onPick,
      trailing: attached
          ? Tap(label: 'Отвязать от пары', onTap: onClear, child: Padding(padding: const EdgeInsets.all(6), child: Text('Убрать'.cased, style: T.captionSemi.copyWith(color: c.link))))
          : null,
    );
  }
}
