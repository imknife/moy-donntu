import 'package:flutter/material.dart';

import '../data/app_controller.dart';
import '../data/specs.dart';
import '../data/schedule_model.dart';
import '../domain/models.dart';
import '../domain/notes.dart';
import '../domain/deadline.dart';
import '../domain/schedule.dart';
import '../domain/time_utils.dart';
import 'common.dart';
import 'derived.dart';
import 'scope.dart';
import 'icons.dart';
import 'lesson_card.dart';
import 'deadline_sheet.dart';
import 'deadlines_page.dart';
import 'note_editor.dart';
import 'note_sheet.dart';
import 'reminder_sheet.dart';
import 'theme.dart';
import 'widgets.dart';
import 'type_settings.dart';

String initials(String name) {
  final parts = name.split(RegExp(r'[\s.]+')).where((p) => p.isNotEmpty).toList();
  return parts.take(2).map((p) => p.substring(0, 1).toUpperCase()).join();
}

class LessonPage extends StatelessWidget {
  const LessonPage({super.key, required this.date, required this.lessonKey, this.group = '', this.subgroup = 0});
  final DateTime date;
  final String lessonKey;
  final String group;
  final int subgroup;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final app = context.app;
    final own = app.store.selection.value.group;
    Widget content(ScheduleModel? model) {
      final item = model?.findLesson(date, lessonKey);
      final cancelled = item == null ? model?.findCancelled(date, lessonKey) : null;
      if (model == null || (item == null && cancelled == null)) {
        return Padding(padding: const EdgeInsets.all(24), child: Text('Занятие не найдено для этой даты и подгруппы'.cased, style: T.body.copyWith(color: c.muted)));
      }
      return _Body(controller: app, model: model, date: date, item: item, cancelled: cancelled, group: group.isEmpty ? own : group);
    }

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            const BackBar(title: ''),
            Expanded(
              child: group.isEmpty || group == own
                  ? ValueListenableBuilder<ScheduleModel?>(valueListenable: app.model, builder: (context, model, _) => content(model))
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ResourceView<GroupPackage>(
                        resource: app.hub.watch(packageSpec(group)),
                        builder: (context, pkg) => content(ScheduleModel(pkg: pkg, subgroup: subgroup, names: app.names, nowInstant: app.clock.now())),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller, required this.model, required this.date, required this.item, required this.cancelled, required this.group});
  final String group;
  final AppController controller;
  final ScheduleModel model;
  final DateTime date;
  final DayLesson? item;
  final CancelledLesson? cancelled;

  @override
  Widget build(BuildContext context) {
    final clock = controller.clock;
    final isToday = sameDay(date, clock.value.today);
    if (!isToday) return _content(context, clock.value.today, clock.value.minute);
    return Derived<int>(
      listenable: clock,
      read: () => clock.value.minute,
      builder: (context, minute) => _content(context, clock.value.today, minute),
    );
  }

  Widget _content(BuildContext context, DateTime today, int minute) {
    final c = context.pal;
    final bell = item?.bell ?? cancelled!.bell;
    final lesson = item?.lesson;
    final subject = lesson?.subject ?? cancelled!.subject;
    final when = date.isBefore(today) ? DayRelation.past : (date.isAfter(today) ? DayRelation.future : DayRelation.today);
    final status = lessonStatus(
      bell: bell,
      override: item?.override,
      change: item?.change,
      teacherPending: item == null ? false : (lesson!.teacherPending || lesson.teachers.isEmpty),
      minuteOfDay: minute.toDouble(),
      when: when,
      cancelled: item == null,
    );
    final rawNote = (item?.overrideNote ?? cancelled?.note ?? '').replaceFirst(RegExp(r'^замена\s*[:—-]?\s*', caseSensitive: false), '').trim();
    final change = item?.change ?? ((item?.override == 'replace' || item?.override == 'add') ? rawNote : '');
    final extras = lesson == null
        ? <String>[]
        : [if (lesson.subgroup != 0) '${lesson.subgroup} подгруппа', if (lesson.week != 'BOTH') weekLabel[lesson.week]!.toLowerCase()];
    final room = lesson?.rooms.where((r) => !r.placeholder).firstOrNull;
    final roomText = lesson != null && roomsLabel(lesson) != 'аудитория не указана' ? roomsLabel(lesson) : '';
    final phaseColor = switch (status.phase) {
      LessonPhase.live || LessonPhase.soon => c.link,
      LessonPhase.cancelled => c.danger,
      LessonPhase.done => c.muted,
      _ => c.text,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (lesson != null) KindChip(kind: lesson.kind),
            Text(status.label, style: T.captionSemi.copyWith(color: phaseColor)),
            if (when != DayRelation.today) Text('· ${dayShort[isoDay(date)]}, ${formatDayDate(date)}', style: T.caption.copyWith(color: c.muted)),
            if (status.replaced) Text('Замена'.cased, style: T.captionSemi.copyWith(color: c.link)),
            if (status.extra) Text('Доп. пара'.cased, style: T.captionSemi.copyWith(color: c.link)),
          ],
        ),
        if (status.phase == LessonPhase.live) ...[
          const SizedBox(height: 8),
          _Progress(ratio: status.progress ?? 0),
        ],
        const SizedBox(height: 10),
        Text(subject, maxLines: 3, overflow: TextOverflow.ellipsis, style: T.lessonTitle.copyWith(color: c.text)),
        if (extras.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(extras.join(' · '), style: T.caption.copyWith(color: c.muted))),
        const SizedBox(height: 10),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _InfoCell(title: '${shortTime(bell.start)}–${shortTime(bell.end)}', detail: formatDuration(bell.endMinutes - bell.startMinutes))),
                    if (roomText.isNotEmpty) ...[
                      Container(width: 1, color: c.hairline),
                      Expanded(
                        child: _InfoCell(
                          title: roomText,
                          detail: room?.building != null ? 'корпус ${room!.building}${room.floor != null && room.floor != 0 ? ' · ${room.floor} этаж' : ''}' : null,
                          onTap: room == null ? null : () => context.open('room', {'room': room.label, 'date': ymd(date), if (group.isNotEmpty) 'group': group}),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (lesson != null && (lesson.teachers.isNotEmpty || status.teacherPending)) _Teachers(lesson: lesson, names: model.names, pending: status.teacherPending),
            ],
          ),
        ),
        if (status.phase == LessonPhase.cancelled) ...[
          const SizedBox(height: 10),
          SurfaceCard(
            color: c.changes,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Пара отменена'.cased, style: T.subject.copyWith(color: c.danger)),
                if (rawNote.isNotEmpty) Text(rawNote, style: T.caption.copyWith(color: c.muted)),
              ],
            ),
          ),
        ],
        if (change.isNotEmpty && status.phase != LessonPhase.cancelled) ...[
          const SizedBox(height: 10),
          SurfaceCard(
            color: c.tint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status.extra ? 'Дополнительная пара' : 'Замена', style: T.captionSemi.copyWith(color: c.link)),
                Text(change, style: T.body.copyWith(color: c.text)),
                if (rawNote.isNotEmpty && rawNote != change) Text(rawNote, style: T.caption.copyWith(color: c.muted)),
              ],
            ),
          ),
        ],
        if (item != null) ..._notes(context, item!, over: status.phase == LessonPhase.done || status.phase == LessonPhase.cancelled),
        if (lesson != null && lesson.stream.isNotEmpty) ...[
          const SectionLabel('Группы потока'),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final g in lesson.stream) MenuRow(icon: 'people', title: g.code, detail: g.subgroup != 0 ? '${g.subgroup} подгруппа' : 'Вся группа', onTap: () => context.open('group', {'group': g.code})),
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _notes(BuildContext context, DayLesson it, {required bool over}) {
    final store = controller.store;
    final dateStr = ymd(date);
    return [
      const SizedBox(height: 12),
      _ActionGrid(actions: [
        ('Заметка', 'note', () => _edit(context, it, null)),
        ('Дедлайн', 'deadline', () => showDeadlineSheet(context, lessonKey: it.key, lessonDate: ymd(date), subject: it.lesson.subject, kind: it.lesson.kind, due: ymd(date))),
        ('Файлы', 'file', () => context.open('materials', {'key': it.key, 'subject': it.lesson.subject})),
        if (controller.native.available && !over && !date.isBefore(controller.clock.value.today)) ('Напомнить', 'bell', () => showReminderSheet(context, date: date, lesson: it)),
        if (controller.features.value.campus && buildingOf(it.lesson) != null) ('Корпус', 'campus', () => context.open('campus', _campusParams(it))),
      ]),
      ValueListenableBuilder<List<Deadline>>(
        valueListenable: store.deadlines,
        builder: (context, all, _) {
          final list = deadlinesForLesson(all, it.key, dateStr);
          if (list.isEmpty) return const SizedBox.shrink();
          final today = controller.clock.value.today;
          final minute = controller.clock.value.minute;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Дедлайны'),
              for (final d in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SurfaceCard(
                    padding: EdgeInsets.zero,
                    child: DeadlineRow(item: d, today: today, minute: minute),
                  ),
                ),
            ],
          );
        },
      ),
      ValueListenableBuilder<List<Note>>(
        valueListenable: store.notes,
        builder: (context, all, _) {
          final list = notesForLesson(all, it.key, dateStr);
          if (list.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Заметки'),
              for (final n in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SurfaceCard(
                    onTap: () => _edit(context, it, n),
                    child: NoteBody(text: n.text, onToggle: (index) => store.saveNote(n.copyWith(text: toggleLine(n.text, index), updatedAt: DateTime.now().toUtc().toIso8601String()))),
                  ),
                ),
            ],
          );
        },
      ),
    ];
  }

  Map<String, String> _campusParams(DayLesson it) {
    final building = buildingOf(it.lesson);
    final before = model.items(date).where((x) => x.num < it.num).toList().reversed.map((x) => buildingOf(x.lesson)).firstWhere((b) => b != null, orElse: () => null);
    return {'building': '$building', 'to': '$building', if (before != null) 'from': '$before'};
  }

  void _edit(BuildContext context, DayLesson it, Note? note) {
    if (note != null) {
      showNoteSheet(context, id: note.id);
    } else {
      showNoteSheet(context, lessonKey: it.key, lessonDate: ymd(date), subject: it.lesson.subject, kind: it.lesson.kind);
    }
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.ratio});
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 4,
        child: Stack(children: [
          Positioned.fill(child: ColoredBox(color: c.soft)),
          FractionallySizedBox(widthFactor: ratio.clamp(0.0, 1.0), child: ColoredBox(color: c.link)),
        ]),
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  const _InfoCell({required this.title, this.detail, this.onTap});
  final String title;
  final String? detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: T.heading.copyWith(color: c.text, fontSize: 16, height: 20 / 16)),
        if (detail != null) Text(detail!, style: T.micro.copyWith(color: c.muted)),
      ],
    );
    final cell = Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      alignment: Alignment.centerLeft,
      child: onTap == null
          ? text
          : Row(children: [Expanded(child: text), const SizedBox(width: 8), AppIcon('chevron', size: 16, color: c.muted)]),
    );
    return onTap == null ? cell : Tap(label: title, onTap: onTap!, child: cell);
  }
}

class _Teachers extends StatelessWidget {
  const _Teachers({required this.lesson, required this.names, required this.pending});
  final Lesson lesson;
  final Map<String, String> names;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Column(
      children: [
        for (final teacher in lesson.teachers)
          Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.hairline))),
            child: Tap(
              label: 'Расписание преподавателя ${names[teacher.name] ?? teacher.name}',
              onTap: () => context.open('teacher', {'name': teacher.name}),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                constraints: const BoxConstraints(minHeight: 56),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: c.tint, borderRadius: BorderRadius.circular(10)),
                      alignment: Alignment.center,
                      child: Text(initials(teacher.name), style: T.captionSemi.copyWith(color: c.link)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(names[teacher.name] ?? teacher.name, style: T.subject.copyWith(color: c.text)),
                          if (rankLabel(teacher.rank).isNotEmpty) Text(rankLabel(teacher.rank), style: T.micro.copyWith(color: c.muted)),
                        ],
                      ),
                    ),
                    AppIcon('chevron', size: 16, color: c.muted),
                  ],
                ),
              ),
            ),
          ),
        if (pending)
          Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.hairline))),
            child: const MenuRow(icon: 'teacher', title: 'Преподаватель уточняется'),
          ),
      ],
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.actions});
  final List<(String, String, VoidCallback)> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final perRow = actions.length <= 4 ? actions.length : 3;
    final rows = <List<(String, String, VoidCallback)>>[];
    for (var i = 0; i < actions.length; i += perRow) {
      rows.add(actions.sublist(i, i + perRow > actions.length ? actions.length : i + perRow));
    }
    return Column(
      children: [
        for (var r = 0; r < rows.length; r++)
          Padding(
            padding: EdgeInsets.only(top: r == 0 ? 0 : 8),
            child: Row(
              children: [
                for (var i = 0; i < perRow; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: i < rows[r].length
                        ? Tap(
                            label: rows[r][i].$1,
                            onTap: rows[r][i].$3,
                            child: Container(
                              height: 76,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(color: c.background, borderRadius: BorderRadius.circular(12)),
                                    alignment: Alignment.center,
                                    child: AppIcon(rows[r][i].$2, size: 22, color: c.text),
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(fit: BoxFit.scaleDown, child: Text(rows[r][i].$1, maxLines: 1, style: T.micro.copyWith(color: c.text, fontSize: 12, height: 14 / 12))),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
