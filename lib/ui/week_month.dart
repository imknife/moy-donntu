import 'package:flutter/material.dart';

import '../data/schedule_model.dart';
import '../domain/schedule.dart';
import '../domain/time_utils.dart';
import 'derived.dart';
import 'schedule_env.dart';
import 'widgets.dart';
import 'theme.dart';
import 'type_settings.dart';

const _kindShort = {'lecture': 'ЛЕК', 'practice': 'ПРАК', 'lab': 'ЛАБ', 'exam': 'ЭКЗ', 'credit': 'ЗАЧ'};

const _dayColumn = 44.0;

class WeekView extends StatelessWidget {
  const WeekView({super.key, required this.env});
  final ScheduleEnv env;
  ScheduleModel get model => env.model;
  ValueNotifier<DateTime> get selected => env.selected;
  MskClock get clock => env.clock;
  void Function(DateTime day) get onDay => env.openDay;

  @override
  Widget build(BuildContext context) {
    return Derived<DateTime>(
      listenable: selected,
      read: () => startOfIsoWeek(selected.value),
      builder: (context, monday) {
        final c = context.pal;
        final days = [for (var i = 0; i < 7; i++) addDays(monday, i)];
        final perDay = [for (final d in days) model.items(d)];
        final nums = <int>{for (final l in perDay) for (final x in l) x.num}.toList()..sort();
        if (nums.isEmpty) {
          return Padding(padding: const EdgeInsets.all(16), child: Text('На этой неделе пар нет'.cased, style: T.caption.copyWith(color: c.muted)));
        }
        String startOf(int num) {
          for (final l in perDay) {
            for (final x in l) {
              if (x.num == num) return x.bell.start;
            }
          }
          return '';
        }

        return _Scroll(env: env, children: [
            Row(
              children: [
                const SizedBox(width: _dayColumn),
                for (final num in nums)
                  Expanded(
                    child: Container(
                      height: scaled(context, 44),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FittedBox(fit: BoxFit.scaleDown, child: Text(shortTime(startOf(num)), maxLines: 1, softWrap: false, style: T.microSemi.copyWith(color: c.text, fontSize: 11))),
                          FittedBox(fit: BoxFit.scaleDown, child: Text('$num пара'.cased, maxLines: 1, softWrap: false, style: T.micro.copyWith(color: c.muted, fontSize: 10))),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < 7; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: _dayColumn,
                      child: Tap(
                        label: '${dayShort[isoDay(days[i])]}, ${days[i].day}, открыть день',
                        onTap: () => onDay(days[i]),
                        child: Container(
                          height: scaled(context, 56),
                          margin: const EdgeInsets.only(right: 2),
                          decoration: BoxDecoration(
                            color: sameDay(days[i], selected.value) ? c.tint : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: sameDay(days[i], clock.value.today) && !sameDay(days[i], selected.value) ? c.link : Colors.transparent),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FittedBox(fit: BoxFit.scaleDown, child: Text(dayShort[isoDay(days[i])], maxLines: 1, softWrap: false, style: T.dayName.copyWith(color: c.muted))),
                              FittedBox(fit: BoxFit.scaleDown, child: Text('${days[i].day}', maxLines: 1, softWrap: false, style: T.dayNum.copyWith(color: c.text))),
                            ],
                          ),
                        ),
                      ),
                    ),
                    for (final num in nums)
                      Expanded(
                        child: _Cell(
                          items: perDay[i].where((x) => x.num == num).toList(),
                          onOpen: (items) => items.length == 1 ? env.openLesson(CardRow(items.first, days[i])) : onDay(days[i]),
                        ),
                      ),
                  ],
                ),
              ),
        ]);
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.items, required this.onOpen});
  final List<DayLesson> items;
  final void Function(List<DayLesson> items) onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    if (items.isEmpty) {
      return Container(height: scaled(context, 56), margin: const EdgeInsets.symmetric(horizontal: 2), decoration: BoxDecoration(color: c.soft.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(8)));
    }
    final it = items.first;
    final tone = c.kindTone(it.lesson.kind);
    final room = roomsLabel(it.lesson);
    final roomShort = room.startsWith('аудитория') ? '—' : room.split(',').first;
    final fg = tone?.$1 ?? c.text;
    return Tap(
      label: '${kindLabel[it.lesson.kind] ?? 'Занятие'}, ${it.num} пара, ${items.length > 1 ? 'открыть день' : 'открыть занятие'}',
      onTap: () => onOpen(items),
      child: Container(
        height: scaled(context, 56),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(color: tone?.$2 ?? c.soft, borderRadius: BorderRadius.circular(8)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(fit: BoxFit.scaleDown, child: Text(_kindShort[it.lesson.kind] ?? (kindLabel[it.lesson.kind] ?? ''), maxLines: 1, softWrap: false, style: T.microSemi.copyWith(fontSize: 10, color: fg, letterSpacing: 0.3, fontWeight: FontWeight.w700))),
            Text(roomShort, maxLines: 1, overflow: TextOverflow.clip, style: T.microSemi.copyWith(color: fg)),
            if (items.length > 1) Text('+${items.length - 1}', style: T.micro.copyWith(fontSize: 9, color: fg)),
          ],
        ),
      ),
    );
  }
}

class MonthView extends StatelessWidget {
  const MonthView({super.key, required this.env});
  final ScheduleEnv env;
  ScheduleModel get model => env.model;
  ValueNotifier<DateTime> get selected => env.selected;
  MskClock get clock => env.clock;
  void Function(DateTime day) get onDay => env.openDay;

  @override
  Widget build(BuildContext context) {
    return Derived<(int, int)>(
      listenable: selected,
      read: () => (selected.value.year, selected.value.month),
      builder: (context, ym) {
        final c = context.pal;
        final first = DateTime.utc(ym.$1, ym.$2, 1);
        final offset = isoDay(first) - 1;
        final count = DateTime.utc(ym.$1, ym.$2 + 1, 0).day;
        final cells = offset + count;
        final rows = (cells / 7).ceil();
        return _Scroll(env: env, children: [
            Row(
              children: [
                for (var i = 1; i <= 7; i++) Expanded(child: Center(child: Text(dayShort[i], style: T.dayName.copyWith(color: c.muted)))),
              ],
            ),
            const SizedBox(height: 6),
            for (var r = 0; r < rows; r++)
              Row(
                children: [
                  for (var col = 0; col < 7; col++)
                    Expanded(
                      child: () {
                        final n = r * 7 + col - offset + 1;
                        if (n < 1 || n > count) return SizedBox(height: scaled(context, 52));
                        final d = DateTime.utc(ym.$1, ym.$2, n);
                        return _MonthCell(day: d, kinds: model.kinds(d), selected: selected, clock: clock, onDay: onDay);
                      }(),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({required this.day, required this.kinds, required this.selected, required this.clock, required this.onDay});
  final DateTime day;
  final List<String> kinds;
  final ValueNotifier<DateTime> selected;
  final MskClock clock;
  final void Function(DateTime day) onDay;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final sel = sameDay(day, selected.value);
    final isToday = sameDay(day, clock.value.today);
    final accent = sel || isToday;
    return Tap(
      label: '${day.day}',
      onTap: () => onDay(day),
      child: Container(
        height: scaled(context, 52),
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: sel ? c.tint : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isToday && !sel ? c.link : Colors.transparent),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${day.day}', style: (sel ? T.dayNumSel : T.dayNum).copyWith(color: accent ? c.link : c.text)),
            const SizedBox(height: 3),
            SizedBox(
              height: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var n = 0; n < kinds.length; n++)
                    Padding(
                      padding: EdgeInsets.only(left: n == 0 ? 0 : 3),
                      child: Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: c.kindTone(kinds[n])?.$1 ?? c.axis)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Scroll extends StatelessWidget {
  const _Scroll({required this.env, required this.children});
  final ScheduleEnv env;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ScrollReporter(
      env: env,
      child: ValueListenableBuilder<double>(
        valueListenable: env.headerHeight,
        builder: (context, h, _) => ListView(
          padding: EdgeInsets.fromLTRB(16, h, 16, 16),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
              decoration: BoxDecoration(color: context.pal.surface, borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ],
        ),
      ),
    );
  }
}
