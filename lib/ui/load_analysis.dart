import 'package:flutter/material.dart';

import '../data/schedule_model.dart';
import '../domain/schedule.dart';
import '../domain/time_utils.dart';
import 'common.dart';
import 'derived.dart';
import 'scope.dart';
import 'settings_group.dart';
import 'theme.dart';
import 'type_settings.dart';
import 'widgets.dart';

const windowMinutes = 30;
const overloadedHours = 8;

class LoadReport {
  const LoadReport({
    required this.pairs,
    required this.minutes,
    required this.studyDays,
    required this.hoursByWeekday,
    required this.currentWeekday,
    required this.kinds,
    required this.windows,
    required this.gapMinutes,
  });
  final int pairs;
  final int minutes;
  final int studyDays;
  final List<double> hoursByWeekday;
  final int currentWeekday;
  final Map<String, int> kinds;
  final int windows;
  final int gapMinutes;

  double get avgPerDay => studyDays == 0 ? 0 : pairs / studyDays;

  int? get lightestWeekday {
    int? best;
    for (var i = 0; i < hoursByWeekday.length; i++) {
      if (hoursByWeekday[i] > 0 && (best == null || hoursByWeekday[i] < hoursByWeekday[best])) best = i;
    }
    return best;
  }

  int? get overloadedWeekday {
    for (var i = 0; i < hoursByWeekday.length; i++) {
      if (hoursByWeekday[i] >= overloadedHours) return i;
    }
    return null;
  }
}

LoadReport loadReport(ScheduleModel model, DateTime today, {required bool month}) {
  final first = month ? DateTime.utc(today.year, today.month, 1) : startOfIsoWeek(today);
  final count = month ? DateTime.utc(today.year, today.month + 1, 0).day : 7;
  final minutesByWeekday = List.filled(7, 0);
  final datesByWeekday = List.filled(7, 0);
  final kinds = <String, int>{};
  var pairs = 0;
  var minutes = 0;
  var studyDays = 0;
  var windows = 0;
  var gapMinutes = 0;
  var currentWeekday = -1;
  for (var i = 0; i < count; i++) {
    final date = addDays(first, i);
    if (sameDay(date, today)) currentWeekday = isoDay(date) - 1;
    final seen = <int>{};
    final items = [for (final it in model.items(date)) if (seen.add(it.num)) it]..sort((a, b) => a.bell.startMinutes - b.bell.startMinutes);
    if (items.isEmpty) continue;
    studyDays++;
    datesByWeekday[isoDay(date) - 1]++;
    for (var n = 0; n < items.length; n++) {
      final it = items[n];
      final length = it.bell.endMinutes - it.bell.startMinutes;
      pairs++;
      minutes += length;
      minutesByWeekday[isoDay(date) - 1] += length;
      kinds[it.lesson.kind] = (kinds[it.lesson.kind] ?? 0) + 1;
      if (n + 1 < items.length) {
        final gap = items[n + 1].bell.startMinutes - it.bell.endMinutes;
        if (gap >= windowMinutes) {
          windows++;
          gapMinutes += gap;
        }
      }
    }
  }
  return LoadReport(
    pairs: pairs,
    minutes: minutes,
    studyDays: studyDays,
    hoursByWeekday: [for (var i = 0; i < 7; i++) datesByWeekday[i] == 0 ? 0 : minutesByWeekday[i] / 60 / datesByWeekday[i]],
    currentWeekday: currentWeekday,
    kinds: kinds,
    windows: windows,
    gapMinutes: gapMinutes,
  );
}

String decimal(double value) {
  if (value == value.roundToDouble()) return '${value.round()}';
  return value.toStringAsFixed(1).replaceAll('.', ',');
}

class LoadAnalysis extends StatefulWidget {
  const LoadAnalysis({super.key, required this.model, required this.today});
  final ScheduleModel model;
  final DateTime today;

  @override
  State<LoadAnalysis> createState() => _LoadAnalysisState();
}

class _LoadAnalysisState extends State<LoadAnalysis> {
  int _period = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final month = _period == 1;
    final report = loadReport(widget.model, widget.today, month: month);
    final span = month ? 'за месяц' : 'за неделю';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedPill(options: const ['Неделя', 'Месяц'], value: _period, onChanged: (i) => setState(() => _period = i), height: 36),
        const SizedBox(height: 12),
        if (report.pairs == 0)
          _Card(child: Text('В этом периоде пар нет'.cased, style: T.body.copyWith(color: c.muted)))
        else ...[
          Row(
            children: [
              Expanded(child: _Stat(value: decimal(report.minutes / 60), label: 'часов $span')),
              const SizedBox(width: 8),
              Expanded(child: _Stat(value: decimal(double.parse(report.avgPerDay.toStringAsFixed(1))), label: 'ср. пар в день')),
            ],
          ),
          const SizedBox(height: 8),
          _ByDayCard(report: report),
          const SizedBox(height: 8),
          _ByKindCard(report: report),
          const SizedBox(height: 8),
          _Insights(report: report),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.pal.surface, borderRadius: BorderRadius.circular(groupRadius)),
      child: child,
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(groupRadius)),
      child: Column(
        children: [
          Text(value, style: T.title.copyWith(fontSize: 28, height: 32 / 28, color: c.text)),
          const SizedBox(height: 4),
          Text(label, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: T.micro.copyWith(color: c.muted)),
        ],
      ),
    );
  }
}

class _ByDayCard extends StatelessWidget {
  const _ByDayCard({required this.report});
  final LoadReport report;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final peak = report.hoursByWeekday.fold<double>(1, (a, b) => a > b ? a : b);
    final overloaded = report.overloadedWeekday;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Нагрузка по дням', style: T.subject.copyWith(color: c.text)),
          if (overloaded != null) ...[
            const SizedBox(height: 4),
            Text(
              '${dayShort[overloaded + 1]} перегружен — ${report.hoursByWeekday[overloaded].toStringAsFixed(0)} ${plural(report.hoursByWeekday[overloaded].round(), 'час', 'часа', 'часов')}',
              style: T.caption.copyWith(color: c.muted),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 92 + 2 * MediaQuery.textScalerOf(context).scale(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Semantics(
                      label: '${dayShort[i + 1]}: ${report.hoursByWeekday[i] > 0 ? '${decimal(report.hoursByWeekday[i])} ч' : 'пар нет'}',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (report.hoursByWeekday[i] > 0) Text(decimal(report.hoursByWeekday[i]), style: T.micro.copyWith(color: i == report.currentWeekday ? c.text : c.muted)),
                          const SizedBox(height: 4),
                          Container(
                            width: 20,
                            height: report.hoursByWeekday[i] <= 0 ? 3 : (report.hoursByWeekday[i] / peak * 76).clamp(6.0, 76.0),
                            decoration: BoxDecoration(
                              color: report.hoursByWeekday[i] <= 0 ? c.barIdle : c.link,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(dayShort[i + 1], maxLines: 1, style: T.micro.copyWith(color: i == report.currentWeekday ? c.text : c.muted)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ByKindCard extends StatelessWidget {
  const _ByKindCard({required this.report});
  final LoadReport report;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final kinds = report.kinds.entries.toList()..sort((a, b) => b.value - a.value);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('По типу занятий', style: T.subject.copyWith(color: c.text)),
          const SizedBox(height: 14),
          for (var i = 0; i < kinds.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: Text(kindLabel[kinds[i].key] ?? kinds[i].key, style: T.body.copyWith(color: c.text))),
                Text('${(kinds[i].value / report.pairs * 100).round()}%', style: T.body.copyWith(color: c.muted)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: c.background),
                    FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: (kinds[i].value / report.pairs).clamp(0.0, 1.0), child: ColoredBox(color: c.kindTone(kinds[i].key)?.$1 ?? c.axis)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Insights extends StatelessWidget {
  const _Insights({required this.report});
  final LoadReport report;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final lightest = report.studyDays > 1 ? report.lightestWeekday : null;
    final rows = <String>[
      if (lightest != null) 'Лучшее утро — ${dayNames[lightest + 1].toLowerCase()}',
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(groupRadius)),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, indent: 16, color: c.hairline),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(rows[i], style: T.subject.copyWith(color: c.text)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class LoadPage extends StatelessWidget {
  const LoadPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return PageScaffold(
      title: 'Нагрузка',
      children: [
        Derived<int>(
          listenable: Listenable.merge([app.model, app.clock]),
          read: () => Object.hash(app.model.value, app.clock.value),
          builder: (context, _) {
            final model = app.model.value;
            if (model == null) return const EmptyBox(icon: 'chart', title: 'Расписание не загружено');
            return LoadAnalysis(model: model, today: app.clock.value.today);
          },
        ),
      ],
    );
  }
}
