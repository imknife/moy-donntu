import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/specs.dart';
import '../domain/models.dart';
import '../domain/schedule.dart';
import '../domain/time_utils.dart';
import 'common.dart';
import 'derived.dart';
import 'icons.dart';
import 'scope.dart';
import 'settings_group.dart';
import 'theme.dart';
import 'type_settings.dart';

const _twoColumnLimit = 14;

DateTime? _firstDate(LessonChange change, DateTime published, String? semesterStart) {
  var day = DateTime.utc(published.year, published.month, published.day);
  for (var i = 0; i < 15; i++) {
    final parityKnown = change.week == 'BOTH' || semesterStart != null;
    if (isoDay(day) == change.day && parityKnown && (change.week == 'BOTH' || weekTypeFor(day, semesterStart) == change.week)) return day;
    day = addDays(day, 1);
  }
  return null;
}

const _fieldLabels = {'teachers': 'Преподаватель', 'rooms': 'Аудитория', 'subject': 'Предмет', 'kind': 'Вид занятия', 'stream': 'Группы потока'};

String _fieldValue(FieldChange field, String raw) => field.field == 'kind' ? (kindLabel[raw] ?? raw) : raw;

Color _kindColor(Pal c, String type) => switch (type) {
      'added' => c.dark ? const Color(0xFF6FCF97) : const Color(0xFF1E7B45),
      'removed' => c.danger,
      _ => c.dark ? const Color(0xFFF2B84B) : const Color(0xFF9A5B00),
    };

String _kindLabel(String type) => switch (type) {
      'added' => 'Новая',
      'removed' => 'Убрана',
      _ => 'Изменена',
    };

String _stamp(String iso) {
  final t = DateTime.tryParse(iso);
  if (t == null) return iso;
  final d = toMsk(t);
  String p(int n) => n.toString().padLeft(2, '0');
  return '${d.day} ${monthsGenitive[d.month - 1]}, ${p(d.hour)}:${p(d.minute)}';
}

class ChangesPage extends StatefulWidget {
  const ChangesPage({super.key});

  @override
  State<ChangesPage> createState() => _ChangesPageState();
}

class _ChangesPageState extends State<ChangesPage> {
  final Set<int> _flipped = {};

  bool _isOpen(List<ChangeVersion> versions, ChangeVersion v) {
    final newest = versions.map((x) => x.version).reduce(math.max);
    final byDefault = v.version == newest;
    return _flipped.contains(v.version) ? !byDefault : byDefault;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.pal;
    final group = app.store.selection.value.group;
    final bells = app.model.value?.pkg.bells ?? defaultBells;
    return PageScaffold(
      title: 'Изменения',
      children: [
        if (group.isEmpty)
          PrimaryButton(label: 'Выбрать группу', onTap: () => context.open('groups'))
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text('$group · история публикаций'.cased, style: T.caption.copyWith(color: c.muted)),
          ),
          ResourceView<List<ChangeVersion>>(
            resource: app.hub.watch(changesSpec(group)),
            builder: (context, versions) {
              if (versions.isEmpty) return const EmptyBox(icon: 'sun', title: 'Новых изменений нет');
              final ordered = [...versions]..sort((a, b) => b.version.compareTo(a.version));
              return Column(
                children: [
                  for (final v in ordered)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _VersionIsland(
                        version: v,
                        bells: bells,
                        semesterStart: app.model.value?.pkg.semesterStart,
                        open: _isOpen(versions, v),
                        onToggle: () => setState(() => _flipped.contains(v.version) ? _flipped.remove(v.version) : _flipped.add(v.version)),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _VersionIsland extends StatelessWidget {
  const _VersionIsland({required this.version, required this.bells, required this.semesterStart, required this.open, required this.onToggle});
  final ChangeVersion version;
  final BellGrids bells;
  final String? semesterStart;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final changes = version.changes;
    final initial = version.version == 1 || changes.isEmpty;
    final counts = {
      'added': changes.where((x) => x.type == 'added').length,
      'changed': changes.where((x) => x.type != 'added' && x.type != 'removed').length,
      'removed': changes.where((x) => x.type == 'removed').length,
    };
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_stamp(version.publishedAt).cased, style: T.heading.copyWith(color: c.text)),
                if (initial)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Первая публикация расписания'.cased, style: T.caption.copyWith(color: c.muted)),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final entry in counts.entries)
                          if (entry.value > 0) _Pill(label: '${entry.value} ${_countWord(entry.key)}', color: _kindColor(c, entry.key)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (!initial)
            Transform.rotate(angle: open ? math.pi / 2 : 0, child: AppIcon('chevron', size: 18, color: c.muted)),
        ],
      ),
    );
    final head = initial ? header : Tap(onTap: onToggle, label: 'Публикация ${_stamp(version.publishedAt)}', child: header);
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: c.island, borderRadius: BorderRadius.circular(groupRadius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          head,
          if (!initial && open) ..._days(context, changes),
        ],
      ),
    );
  }

  String _countWord(String key) => switch (key) {
        'added' => 'добавлено',
        'removed' => 'убрано',
        _ => 'изменено',
      };

  List<Widget> _days(BuildContext context, List<LessonChange> changes) {
    final c = context.pal;
    final byDay = <int, List<LessonChange>>{};
    for (final ch in changes) {
      byDay.putIfAbsent(ch.day, () => []).add(ch);
    }
    final days = byDay.keys.toList()..sort();
    return [
      for (final day in days) ...[
        Divider(height: 1, thickness: 1, color: c.hairline),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
          child: Text(TypeSettings.caps(dayNames[day]), style: T.sectionLabel.copyWith(color: c.muted)),
        ),
        for (final ch in (byDay[day]!..sort((a, b) => a.num.compareTo(b.num))))
          _ChangeLine(change: ch, start: _start(day, ch.num), from: _fromText(ch)),
        const SizedBox(height: 6),
      ],
    ];
  }

  String? _fromText(LessonChange change) {
    final published = DateTime.tryParse(version.publishedAt);
    if (published == null) return null;
    final date = _firstDate(change, toMsk(published), semesterStart);
    return date == null ? null : 'с ${date.day} ${monthsGenitive[date.month - 1]}';
  }

  String? _start(int day, int num) {
    for (final b in bellsForDay(bells, day)) {
      if (b.num == num) return b.start;
    }
    return null;
  }
}

class _ChangeLine extends StatelessWidget {
  const _ChangeLine({required this.change, required this.start, required this.from});
  final LessonChange change;
  final String? start;
  final String? from;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final color = _kindColor(c, change.type);
    final fields = change.type == 'added' || change.type == 'removed' ? const <FieldChange>[] : (change.fields ?? const <FieldChange>[]);
    final week = weekLabel[change.week];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${change.num} пара'.cased, style: T.microSemi.copyWith(color: c.text)),
                if (start != null) Text(start!, style: T.micro.copyWith(color: c.muted)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(change.subject, style: T.subject.copyWith(color: c.text)),
                if (week != null || from != null) Text([?week, ?from].join(' · ').cased, style: T.micro.copyWith(color: c.muted)),
                for (final f in fields) _FieldLine(field: f),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Pill(label: _kindLabel(change.type), color: color),
        ],
      ),
    );
  }
}

class _FieldLine extends StatelessWidget {
  const _FieldLine({required this.field});
  final FieldChange field;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    String value(String v) => v.isEmpty ? 'не указано' : v;
    Widget cell(String label, String text, {required bool after}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.cased, style: T.micro.copyWith(color: c.muted)),
            Text(value(text), style: T.caption.copyWith(color: after ? c.text : c.muted, fontWeight: after ? FontWeight.w600 : FontWeight.w400)),
          ],
        );
    final from = _fieldValue(field, field.from);
    final to = _fieldValue(field, field.to);
    final before = cell('Было', from, after: false);
    final after = cell('Стало', to, after: true);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text((_fieldLabels[field.field] ?? 'Изменено').cased, style: T.microMedium.copyWith(color: c.text)),
          const SizedBox(height: 2),
          if (from.length <= _twoColumnLimit && to.length <= _twoColumnLimit)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: before), const SizedBox(width: 12), Expanded(child: after)])
          else ...[before, const SizedBox(height: 4), after],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
        child: Text(label.cased, style: T.microSemi.copyWith(color: color)),
      );
}
