import 'package:flutter/material.dart';

import '../domain/schedule.dart';
import '../domain/time_utils.dart';
import 'lesson_card.dart';
import 'lesson_route.dart';
import 'scope.dart';
import 'sheet.dart';
import 'theme.dart';

Future<void> showLessonPreview(BuildContext context, {required DateTime date, required DayLesson item, required String group, required int subgroup, String? groups}) {
  final app = context.app;
  final lesson = item.lesson;
  return showAppSheet<void>(
    context,
    title: lesson.subject,
    subtitle: '${dayNames[isoDay(date)]}, ${formatDayDate(date)}',
    builder: (ctx) {
      final c = ctx.pal;
      final teacher = teachersLabel(lesson, app.names);
      final rooms = roomsLabel(lesson);
      Widget cell(String label, String value) => Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: T.micro.copyWith(color: c.muted)),
                  const SizedBox(height: 2),
                  Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.subject.copyWith(color: c.text)),
                ],
              ),
            ),
          );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(alignment: Alignment.centerLeft, child: KindChip(kind: lesson.kind)),
          const SizedBox(height: 12),
          Row(children: [
            cell('Время', '${shortTime(item.bell.start)}–${shortTime(item.bell.end)}'),
            const SizedBox(width: 8),
            cell('Аудитория', rooms.isEmpty ? 'Не указана' : rooms),
          ]),
          if (teacher.isNotEmpty || (groups != null && groups.isNotEmpty)) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (teacher.isNotEmpty) ...[
                    Text('Преподаватель', style: T.micro.copyWith(color: c.muted)),
                    Text(teacher, style: T.subject.copyWith(color: c.text)),
                  ],
                  if (groups != null && groups.isNotEmpty) ...[
                    if (teacher.isNotEmpty) const SizedBox(height: 8),
                    Text('Группы', style: T.micro.copyWith(color: c.muted)),
                    Text(groups, style: T.body.copyWith(color: c.text)),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SheetButton(
            label: 'Открыть пару',
            onTap: () {
              Navigator.of(ctx).pop();
              openLesson(context, date: date, group: group, subgroup: subgroup, key: item.key, slot: item.num);
            },
          ),
        ],
      );
    },
  );
}
