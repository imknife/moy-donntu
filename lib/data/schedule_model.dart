import 'package:flutter/foundation.dart';

import '../domain/models.dart';
import '../domain/schedule.dart';
import '../domain/time_utils.dart';

int epochDay(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

sealed class RowSpec {
  const RowSpec();
}

class CardRow extends RowSpec {
  const CardRow(this.item, this.date);
  final DayLesson item;
  final DateTime date;
}

class GapRow extends RowSpec {
  const GapRow(this.minutes);
  final int minutes;
}

class EmptyRow extends RowSpec {
  const EmptyRow(this.title, [this.text]);
  final String title;
  final String? text;
}

class CancelledRow extends RowSpec {
  const CancelledRow(this.lesson, this.date);
  final CancelledLesson lesson;
  final DateTime date;
}

class ScheduleModel {
  ScheduleModel({required this.pkg, required this.subgroup, required this.names, required this.nowInstant});
  final GroupPackage pkg;
  final int subgroup;
  final Map<String, String> names;
  final DateTime nowInstant;

  final Map<int, List<DayLesson>> _items = {};
  final Map<int, List<RowSpec>> _rows = {};
  final Map<int, List<String>> _kinds = {};
  final Map<int, List<CancelledLesson>> _cancelled = {};

  List<DayLesson> items(DateTime d) => _items[epochDay(d)] ??= lessonsForDate(pkg, d, subgroup, nowInstant);

  List<CancelledLesson> cancelled(DateTime d) => _cancelled[epochDay(d)] ??= cancelledForDate(pkg, d, subgroup);

  int pairs(DateTime d) => pairsCount(items(d));

  List<String> kinds(DateTime d) => _kinds[epochDay(d)] ??= _kindsOf(items(d));

  static List<String> _kindsOf(List<DayLesson> list) {
    final seen = <int, String>{};
    for (final x in list) {
      seen.putIfAbsent(x.num, () => x.lesson.kind);
    }
    return seen.values.take(4).toList(growable: false);
  }

  DayLesson? findLesson(DateTime d, String key) {
    for (final x in items(d)) {
      if (x.key == key) return x;
    }
    return null;
  }

  CancelledLesson? findCancelled(DateTime d, String key) {
    for (final x in cancelled(d)) {
      if (cancelledKey(x.num) == key) return x;
    }
    return null;
  }

  List<RowSpec> rows(DateTime d, {required bool showCancelled, int? hideEndedBefore}) {
    if (hideEndedBefore != null) return _build(d, showCancelled, hideEndedBefore);
    return _rows[epochDay(d) * 2 + (showCancelled ? 1 : 0)] ??= _build(d, showCancelled, null);
  }

  List<RowSpec> _build(DateTime d, bool showCancelled, int? hideEndedBefore) {
    final all = items(d);
    final visible = hideEndedBefore == null ? all : all.where((x) => x.bell.endMinutes > hideEndedBefore).toList();
    final rows = <RowSpec>[];
    final next = visible.isEmpty ? nextStudyDay(pkg, d, subgroup, nowInstant) : null;
    if (visible.isNotEmpty) {
      _addCards(rows, visible, d);
    } else {
      final title = all.isNotEmpty ? 'Занятия закончились' : (_holiday(d) ?? 'Свободный день');
      rows.add(EmptyRow(title, next == null ? 'Расписание появится после публикации' : null));
    }
    if (showCancelled) {
      for (final c in cancelled(d)) {
        rows.add(CancelledRow(c, d));
      }
    }
    return rows;
  }

  String? _holiday(DateTime d) {
    final s = ymd(d);
    for (final h in pkg.calendar?.holidays ?? const <Holiday>[]) {
      if (h.date == s) return h.name;
    }
    return null;
  }

  static void _addCards(List<RowSpec> rows, List<DayLesson> list, DateTime date) {
    for (var i = 0; i < list.length; i++) {
      if (i > 0) {
        final gap = list[i].bell.startMinutes - list[i - 1].bell.endMinutes;
        if (gap >= windowMin) rows.add(GapRow(gap));
      }
      rows.add(CardRow(list[i], date));
    }
  }
}

class MskClock extends ValueNotifier<({DateTime today, int minute})> {
  MskClock({DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(_read(now ?? DateTime.now));

  final DateTime Function() _now;

  DateTime now() => _now();

  static ({DateTime today, int minute}) _read(DateTime Function() now) {
    final n = toMsk(now());
    return (today: startOfDay(n), minute: n.hour * 60 + n.minute);
  }

  void tick() {
    final v = _read(_now);
    if (v != value) value = v;
  }
}
