import 'package:flutter/material.dart';

import '../data/specs.dart';
import '../domain/models.dart';
import '../domain/study_tools.dart';
import '../domain/time_utils.dart';
import 'common.dart';
import 'derived.dart';
import 'scope.dart';
import 'theme.dart';
import 'widgets.dart';
import 'type_settings.dart';

class _NoGroup extends StatelessWidget {
  const _NoGroup();

  @override
  Widget build(BuildContext context) => EmptyBox(icon: 'people', title: 'Группа не выбрана', text: 'Сервис берёт данные из расписания вашей группы.', actionLabel: 'Выбрать группу', onAction: () => context.open('groups'));
}

Widget _withPackage(BuildContext context, String title, Widget Function(BuildContext context, GroupPackage pkg, DateTime nowMsk) builder) {
  final app = context.app;
  final group = app.store.selection.value.group;
  return PageScaffold(
    title: title,
    children: [
      if (group.isEmpty)
        const _NoGroup()
      else
        ResourceView<GroupPackage>(
          resource: app.hub.watch(packageSpec(group)),
          builder: (context, pkg) => Derived<({DateTime today, int minute})>(
            listenable: app.clock,
            read: () => app.clock.value,
            builder: (context, now) => builder(context, pkg, now.today.add(Duration(minutes: now.minute))),
          ),
        ),
    ],
  );
}

class BellsPage extends StatefulWidget {
  const BellsPage({super.key});

  @override
  State<BellsPage> createState() => _BellsPageState();
}

class _BellsPageState extends State<BellsPage> {
  int? _tab;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.pal;
    final group = app.store.selection.value.group;
    final today = app.clock.value.today;
    final weekend = isoDay(today) >= 6;
    final tab = _tab ?? (weekend ? 1 : 0);
    final minute = app.clock.value.minute;
    Widget grid(BellGrids grids) {
      final bells = tab == 1 ? grids.weekend : grids.weekday;
      final live = (tab == 1) == weekend ? bellState(bells, minute) : null;
      return SurfaceCard(child: Column(children: [for (var i = 0; i < bells.length; i++) _bellRow(c, bells, i, live, minute)]));
    }

    return PageScaffold(
      title: 'Расписание звонков',
      children: [
        if (group.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Показана общая сетка donntu.ru — выберите группу, чтобы увидеть звонки из её расписания.'.cased, style: T.caption.copyWith(color: c.muted))),
        SegmentedPill(options: const ['Пн–Пт', 'Сб–Вс'], value: tab, onChanged: (i) => setState(() => _tab = i), height: 36),
        const VGap(8),
        if (group.isEmpty) grid(defaultBells) else ResourceView<GroupPackage>(resource: app.hub.watch(packageSpec(group)), builder: (context, pkg) => grid(pkg.bells ?? defaultBells)),
      ],
    );
  }

  Widget _bellRow(Pal c, List<Bell> bells, int i, ({String kind, int num})? live, int minute) {
    final bell = bells[i];
    final running = live?.kind == 'pair' && live?.num == bell.num;
    final next = i + 1 < bells.length ? bells[i + 1] : null;
    final pause = next == null ? 0 : next.startMinutes - bell.endMinutes;
    final breakNow = live?.kind == 'break' && next != null && live?.num == next.num;
    return Column(children: [
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: running ? c.link : c.soft, borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Text('${bell.num}', style: T.captionSemi.copyWith(color: running ? c.onLink : c.text)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('${shortTime(bell.start)} – ${shortTime(bell.end)}', style: T.subject.copyWith(color: c.text, fontSize: 16))),
          if (running) Text('ещё ${formatDuration(bell.endMinutes - minute)}'.cased, style: T.caption.copyWith(color: c.link)),
        ]),
      ),
      if (pause > 0)
        Padding(
          padding: const EdgeInsets.only(left: 42),
          child: SizedBox(
            height: 28,
            width: double.infinity,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(breakNow ? 'Перемена · до звонка ${formatDuration(next.startMinutes - minute)}' : 'Перемена ${formatDuration(pause)}', style: T.caption.copyWith(color: breakNow ? c.link : c.muted)),
            ),
          ),
        ),
    ]);
  }
}

class AcademicPage extends StatelessWidget {
  const AcademicPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return _withPackage(context, 'Учебный график', (context, pkg, now) {
      final calendar = pkg.calendar;
      final period = currentPeriod(calendar, now);
      final week = _weekNumber(now, pkg.semesterStart);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SurfaceCard(
          color: c.tint,
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('СЕЙЧАС'.cased, style: T.captionSemi.copyWith(color: c.link)),
            Text(period != null ? (periodName[period.kind] ?? '') : 'Вне графика', style: T.display.copyWith(color: c.text, fontSize: 30, height: 1.2)),
            Text(week > 0 ? '$week-я учебная неделя' : 'Семестр ещё не начался', style: T.body.copyWith(color: c.muted)),
          ]),
        ),
        if (calendar == null)
          const Padding(padding: EdgeInsets.only(top: 12), child: EmptyBox(icon: 'academic', title: 'График не опубликован', text: 'Для этой группы учебный график ещё не загружен.'))
        else ...[
          const SectionLabel('Периоды'),
          RowsCard(children: [
            for (final p in calendar.periods)
              MenuRow(
                icon: switch (p.kind) { 'exams' => 'session', 'credits' => 'exam', 'break' => 'sun', _ => 'lecture' },
                title: periodName[p.kind] ?? p.kind,
                detail: '${formatDayDate(parseYmd(p.from)!)} – ${formatDayDate(parseYmd(p.to)!)}',
                trailing: identical(p, period) ? Text('сейчас'.cased, style: T.caption.copyWith(color: c.link)) : const SizedBox(width: 0),
              ),
          ]),
          if (calendar.holidays.isNotEmpty) ...[
            const SectionLabel('Праздники'),
            RowsCard(children: [for (final h in calendar.holidays) MenuRow(icon: 'star', title: h.name, detail: humanDate(h.date), trailing: const SizedBox(width: 0))]),
          ],
        ],
      ]);
    });
  }

  int _weekNumber(DateTime date, String? start) {
    final s = start == null ? null : parseYmd(start);
    if (s == null) return 0;
    final weeks = (startOfIsoWeek(date).difference(startOfIsoWeek(s)).inMilliseconds / (7 * 86400000)).round();
    return weeks >= 0 ? weeks + 1 : 0;
  }
}

class SessionPage extends StatelessWidget {
  const SessionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return _withPackage(context, 'Сессия', (context, pkg, now) {
      final status = sessionStatus(pkg.calendar, now);
      final Widget content = switch (status) {
        SessionAhead() => _countdown(c, 'ДО СЕССИИ', status.days, status.period),
        SessionRunning() => _countdown(c, 'ИДЁТ СЕССИЯ · ОСТАЛОСЬ', status.daysLeft, status.period),
        SessionOver() => const EmptyBox(icon: 'session', title: 'Сессия позади', text: 'Следующая появится вместе с новым учебным графиком.'),
        SessionNone() => const EmptyBox(icon: 'session', title: 'Даты сессии не опубликованы', text: 'Как только график загрузят, здесь появится обратный отсчёт.'),
      };
      return Column(children: [
        content,
        const VGap(8),
        RowsCard(children: [
          MenuRow(icon: 'gradebook', title: 'Зачётная книжка и оценки', detail: 'Оценки по семестрам', onTap: () => context.open('gradebook')),
          MenuRow(icon: 'academic', title: 'Учебный график', onTap: () => context.open('academic')),
        ]),
      ]);
    });
  }

  Widget _countdown(Pal c, String label, int days, Period period) => SurfaceCard(
        color: c.tint,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Column(children: [
          Text(label, style: T.captionSemi.copyWith(color: c.link)),
          Text('$days', style: T.display.copyWith(color: c.text, fontSize: 56, height: 64 / 56, fontWeight: FontWeight.w600)),
          Text(pluralDays(days).replaceFirst(RegExp(r'^\d+ '), ''), style: T.body.copyWith(color: c.muted)),
          Text('${formatDayDate(parseYmd(period.from)!)} – ${formatDayDate(parseYmd(period.to)!)}', style: T.caption.copyWith(color: c.muted)),
        ]),
      );
}
