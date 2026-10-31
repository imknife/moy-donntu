import 'package:flutter/material.dart';

import '../data/schedule_model.dart';
import '../domain/deadline.dart';
import '../domain/models.dart';
import '../domain/notices.dart';
import '../domain/now_card.dart';
import '../domain/schedule.dart';
import '../domain/time_utils.dart';
import 'common.dart';
import 'deadline_sheet.dart';
import 'deadlines_page.dart';
import 'quick_actions.dart';
import 'derived.dart';
import 'icons.dart';
import 'lesson_card.dart';
import 'lesson_route.dart';
import 'notices_page.dart';
import 'scope.dart';
import 'settings_group.dart';
import 'theme.dart';
import 'widgets.dart' show scaled;
import 'type_settings.dart';

class OverviewTab extends StatefulWidget {
  const OverviewTab({super.key});

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  final ValueNotifier<DateTime?> _day = ValueNotifier(null);

  @override
  void dispose() {
    _day.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.app;
    return SafeArea(
      bottom: false,
      child: Derived<(ScheduleModel?, ({DateTime today, int minute}), int)>(
        listenable: Listenable.merge([c.model, c.clock, c.store.notes, c.store.deadlines, c.store.prefs, c.store.selection, c.features, c.brand, c.session, c.auth.student, _day]),
        read: () => (c.model.value, c.clock.value, c.store.notes.value.length + c.store.deadlines.value.hashCode + c.store.prefs.value.hashCode + c.store.selection.value.hashCode + c.features.value.hashCode + c.brand.value.hashCode + (c.session.value == null ? 0 : 1) + c.auth.student.value.hashCode + (_day.value?.millisecondsSinceEpoch ?? 0)),
        builder: (context, _) => _content(context),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final app = context.app;
    final pal = context.pal;
    final model = app.model.value;
    final today = app.clock.value.today;
    final minute = app.clock.value.minute;
    final sel = app.store.selection.value;
    final picked = _day.value;
    final shown = picked ?? today;
    final onToday = sameDay(shown, today);
    final items = model?.items(today) ?? const <DayLesson>[];
    String? holiday;
    for (final h in model?.pkg.calendar?.holidays ?? const <Holiday>[]) {
      if (h.date == ymd(today)) holiday = h.name;
    }
    final card = model == null ? null : nowCardModel(items: items, minute: minute.toDouble(), today: true, dayOffName: holiday);
    final after = card == null ? null : _lessonAfter(card, items);
    final changes = model?.pkg.lastChange?.changes ?? const <LessonChange>[];
    final deadlines = app.store.deadlines.value;
    final openList = [for (final d in deadlines) if (!d.done) d]..sort(deadlineOrder);
    final overdue = overdueDeadlines(deadlines, today, minute);
    Widget action(String label, String icon, String route) => Tap(
          label: label,
          onTap: () => context.open(route),
          child: SizedBox(width: 44, height: 40, child: Center(child: AppIcon(icon, size: 22, color: pal.text))),
        );
    return RefreshIndicator(
      onRefresh: app.refreshAll,
      color: pal.link,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: _DateBlock(date: today))),
              Transform.translate(offset: const Offset(11, 0), child: Row(children: [action('Поиск', 'search', 'search'), const NoticeBell()])),
            ],
          ),
          if (sel.group.isEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: PrimaryButton(label: 'Выбрать группу', onTap: () => context.open('groups'))),
          if (model != null) ...[
            const SizedBox(height: 12),
            _DayStrip(model: model, today: today, selected: shown, onSelect: (d) => _day.value = sameDay(d, today) ? null : d),
          ],
          if (model != null && card != null && onToday) ...[
            const SizedBox(height: 12),
            NowCard(model: card, date: today, group: sel.group, subgroup: sel.subgroup, names: app.names),
            if (after != null) ...[
              const _Label('Дальше'),
              _Island(children: [_NextRow(lesson: after, date: today, group: sel.group, subgroup: sel.subgroup)]),
            ],
          ],
          if (model != null && !onToday) _DayList(model: model, date: shown, group: sel.group, subgroup: sel.subgroup),
          const _Label('Дедлайны'),
          _Island(children: [
            if (openList.isEmpty)
              _MoreRow(icon: 'deadline', title: 'Дедлайнов нет', detail: 'Добавить срок сдачи', onTap: () => showDeadlineSheet(context))
            else ...[
              for (final d in openList.take(3)) DeadlineRow(item: d, today: today, minute: minute),
              _MoreRow(
                icon: 'deadline',
                title: 'Все дедлайны',
                detail: '${openList.length} ${plural(openList.length, 'активный', 'активных', 'активных')}${overdue > 0 ? ' · просрочено $overdue' : ''}',
                onTap: () => context.open('deadlines'),
              ),
            ],
          ]),
          _Label('Быстрые действия', action: 'Изменить', onAction: () => showQuickEditor(context)),
          const QuickActions(),
          if (changes.isNotEmpty) ...[
            const _Label('Изменения'),
            _Island(children: [for (final ch in changes.take(3)) _ChangeRow(change: ch, onTap: () => context.open('changes'))]),
          ],
        ],
      ),
    );
  }

  DayLesson? _lessonAfter(NowCardModel card, List<DayLesson> items) {
    if (card.kind == NowCardKind.live) return card.nextLesson;
    final lesson = card.lesson;
    if (lesson == null) return null;
    final index = items.indexOf(lesson);
    for (var i = index + 1; i < items.length; i++) {
      if (items[i].num != lesson.num) return items[i];
    }
    return null;
  }

}

class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.model, required this.today, required this.selected, required this.onSelect});
  final ScheduleModel model;
  final DateTime today;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final monday = startOfIsoWeek(today);
    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Builder(builder: (context) {
              final day = addDays(monday, i);
              final isSel = sameDay(day, selected);
              final isToday = sameDay(day, today);
              final kinds = model.kinds(day);
              final off = model.pairs(day) == 0;
              return Tap(
                label: '${dayShort[isoDay(day)]}, ${day.day}',
                onTap: () => onSelect(day),
                child: Container(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  decoration: BoxDecoration(
                    color: isSel ? c.tint : c.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isToday && !isSel ? c.link : Colors.transparent),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(dayShort[isoDay(day)], style: T.dayName.copyWith(color: isSel || isToday ? c.link : c.muted)),
                      SizedBox(height: scaled(context, 26), child: Center(child: Text('${day.day}', style: (isSel ? T.dayNumSel : T.dayNum).copyWith(color: isSel || isToday ? c.link : (off ? c.muted : c.text))))),
                      SizedBox(
                        height: 5,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var n = 0; n < kinds.length; n++)
                              Padding(
                                padding: EdgeInsets.only(left: n == 0 ? 0 : 3),
                                child: Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: c.kindTone(kinds[n])?.$1 ?? c.axis)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _DayList extends StatelessWidget {
  const _DayList({required this.model, required this.date, required this.group, required this.subgroup});
  final ScheduleModel model;
  final DateTime date;
  final String group;
  final int subgroup;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final seen = <int>{};
    final items = [for (final it in model.items(date)) if (seen.add(it.num)) it];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label('${dayNames[isoDay(date)]}, ${formatDayDate(date)}${items.isEmpty ? '' : ' · ${pluralLessons(items.length)}'}'),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(groupRadius)),
            child: Text('Свободный день'.cased, style: T.body.copyWith(color: c.muted)),
          )
        else
          _Island(children: [for (final it in items) _NextRow(lesson: it, date: date, group: group, subgroup: subgroup)]),
      ],
    );
  }
}

class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('${date.day}', style: T.numeral.copyWith(color: c.text)),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(monthsGenitive[date.month - 1].cased, style: T.heading.copyWith(fontWeight: FontWeight.w500, fontSize: 20, height: 24 / 20, color: c.text)),
                const SizedBox(height: 2),
                Text(dayNames[isoDay(date)], style: T.caption.copyWith(height: 16 / 13, color: c.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(TypeSettings.caps(text), style: T.sectionLabel.copyWith(color: c.muted))),
          if (action != null && onAction != null)
            Tap(
              label: action!,
              onTap: onAction!,
              child: Text(action!, style: T.captionSemi.copyWith(color: c.link)),
            ),
        ],
      ),
    );
  }
}

class _Island extends StatelessWidget {
  const _Island({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(Divider(height: 1, thickness: 1, color: c.hairline));
      rows.add(children[i]);
    }
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(groupRadius)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
    );
  }
}

class _NextRow extends StatelessWidget {
  const _NextRow({required this.lesson, required this.date, required this.group, required this.subgroup});
  final DayLesson lesson;
  final DateTime date;
  final String group;
  final int subgroup;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Tap(
      label: '${shortTime(lesson.bell.start)}, ${lesson.lesson.subject}',
      onTap: () => openLesson(context, date: date, group: group, subgroup: subgroup, key: lesson.key, slot: lesson.num),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 48, child: Text(shortTime(lesson.bell.start), style: T.bodyLink.copyWith(height: 20 / 15, color: c.muted))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lesson.lesson.subject, maxLines: 3, overflow: TextOverflow.ellipsis, style: T.subject.copyWith(color: c.text)),
                  const SizedBox(height: 4),
                  Align(alignment: Alignment.centerLeft, child: KindChip(kind: lesson.lesson.kind, solid: true)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.change, required this.onTap});
  final LessonChange change;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final (verb, tail) = changeVerb(change);
    final base = T.bodyLink.copyWith(fontWeight: FontWeight.w400, height: 20 / 15, color: c.text);
    return Tap(
      onTap: onTap,
      label: '${change.subject}, $verb$tail',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(style: base, children: [
                TextSpan(text: '${change.subject} в ${dayShort[change.day].toLowerCase()} '),
                TextSpan(text: verb, style: base.copyWith(fontWeight: FontWeight.w500, color: c.link)),
                TextSpan(text: tail),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({required this.icon, required this.title, this.detail, required this.onTap});
  final String icon;
  final String title;
  final String? detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Tap(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: c.background, borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: AppIcon(icon, size: 18, color: c.text),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.subject.copyWith(fontSize: 16, height: 20 / 16, color: c.text)),
                    if (detail != null) Text(detail!, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caption.copyWith(height: 16 / 13, color: c.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppIcon('chevron', size: 16, color: c.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class NowCard extends StatelessWidget {
  const NowCard({super.key, required this.model, required this.date, required this.group, required this.subgroup, required this.names});
  final NowCardModel model;
  final DateTime date;
  final String group;
  final int subgroup;
  final Map<String, String> names;

  String? get _countdown {
    final minutes = model.countdown;
    if (minutes == null) return null;
    final span = countdownParts(minutes).map((p) => '${p.value} ${p.unit}').join(' ');
    return switch (model.kind) {
      NowCardKind.live => 'Осталось $span',
      NowCardKind.before => 'Через $span',
      NowCardKind.pause => 'Звонок через $span',
      NowCardKind.window => 'Следующая через $span',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final lesson = model.lesson;
    final rooms = lesson == null ? '' : roomsLabel(lesson.lesson);
    final base = T.sentence.copyWith(color: c.text);
    final countdown = _countdown;
    final body = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(groupRadius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lesson != null) ...[
            Text(lesson.lesson.subject, maxLines: 3, overflow: TextOverflow.ellipsis, style: base),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              KindChip(kind: lesson.lesson.kind, solid: true),
              if (rooms != noRoomLabel) Text('ауд. $rooms', style: T.caption.copyWith(color: c.muted)),
            ]),
            if (countdown != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(countdown, style: T.captionSemi.copyWith(color: c.link))),
          ] else
            Text(model.title.cased, style: base),
        ],
      ),
    );
    if (lesson == null) return body;
    return Tap(
      label: '${model.title}: ${lesson.lesson.subject}',
      onTap: () => openLesson(context, date: date, group: group, subgroup: subgroup, key: lesson.key, slot: lesson.num),
      child: body,
    );
  }
}
