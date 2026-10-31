import 'package:flutter/material.dart';

import '../data/schedule_model.dart';
import '../domain/time_utils.dart';
import 'derived.dart';
import 'schedule_env.dart';
import 'theme.dart';
import 'widgets.dart' show scaled;

class DayChips extends StatelessWidget {
  const DayChips({super.key, required this.env});
  final ScheduleEnv env;

  @override
  Widget build(BuildContext context) {
    return Derived<DateTime>(
      listenable: env.selected,
      read: () => startOfIsoWeek(env.selected.value),
      builder: (context, monday) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(child: _Chip(key: ValueKey(i), day: addDays(monday, i), kinds: env.model.kinds(addDays(monday, i)), selected: env.selected, clock: env.clock)),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.day, required this.kinds, required this.selected, required this.clock});
  final DateTime day;
  final List<String> kinds;
  final ValueNotifier<DateTime> selected;
  final MskClock clock;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Derived<bool>(
      listenable: selected,
      read: () => sameDay(selected.value, day),
      builder: (context, sel) {
        final isToday = sameDay(day, clock.value.today);
        final accent = sel || isToday;
        return Tap(
          label: '${dayShort[isoDay(day)]}, ${day.day}',
          onTap: () => selected.value = day,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Container(
                padding: const EdgeInsets.only(top: 2, bottom: 3),
                decoration: BoxDecoration(
                  color: sel ? c.tint : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isToday && !sel ? c.link : Colors.transparent),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(dayShort[isoDay(day)], style: T.dayName.copyWith(color: accent ? c.link : c.muted)),
                    SizedBox(height: scaled(context, 24), child: Center(child: Text('${day.day}', style: (sel ? T.dayNumSel : T.dayNum).copyWith(color: accent ? c.link : c.text)))),
                    const SizedBox(height: 1),
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
            ),
          ),
        );
      },
    );
  }
}
