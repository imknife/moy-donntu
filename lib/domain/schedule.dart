import 'models.dart';
import 'time_utils.dart';

const kindLabel = <String, String>{
  'lecture': 'Лекция',
  'lab': 'Лабораторная',
  'practice': 'Практика',
  'consultation': 'Консультация',
  'coursework': 'Курсовая',
  'credit': 'Зачёт',
  'exam': 'Экзамен',
  'other': 'Занятие',
};

const int windowMin = 60;

const periodLabel = <String, String>{'credits': 'Зачётная неделя', 'exams': 'Сессия', 'break': 'Каникулы'};

class DayLesson {
  const DayLesson({required this.key, required this.num, required this.bell, required this.lesson, required this.override, required this.overrideNote, required this.change});
  final String key;
  final int num;
  final Bell bell;
  final Lesson lesson;

  final String? override;
  final String? overrideNote;
  final String? change;

  factory DayLesson.fromJson(Map<String, dynamic> j) => DayLesson(
        key: j['key'] as String,
        num: j['num'] as int,
        bell: Bell.fromJson(j['bell'] as Map<String, dynamic>),
        lesson: Lesson.fromJson(j['lesson'] as Map<String, dynamic>),
        override: j['override'] as String?,
        overrideNote: j['overrideNote'] as String?,
        change: j['change'] as String?,
      );

  DayLesson withLesson(String newKey, Lesson l) => DayLesson(key: newKey, num: num, bell: bell, lesson: l, override: override, overrideNote: overrideNote, change: change);
}

const String noRoomLabel = 'аудитория не указана';

String roomsLabel(Lesson l) {
  final real = l.rooms.where((r) => !r.placeholder).map((r) => r.label).toList();
  return real.isNotEmpty ? real.join(', ') : noRoomLabel;
}

String teachersLabel(Lesson l, [Map<String, String>? names]) => l.teachers.map((t) => names?[t.name] ?? t.name).join(', ');

bool matchesSubgroup(int lessonSub, int chosen) => chosen == 0 || lessonSub == 0 || lessonSub == chosen;

final _rankPrefix = RegExp(r'^\S+\.\s+');

String? describeChange(LessonChange c) {
  if (c.type == 'added') return 'Новая пара';
  if (c.type == 'removed') return 'Пара убрана';
  final f = c.fields ?? const <FieldChange>[];
  FieldChange? find(String name) {
    for (final x in f) {
      if (x.field == name) return x;
    }
    return null;
  }

  final t = find('teachers');
  if (t != null) {
    final was = t.from.split(',').map((s) => s.trim().replaceFirst(_rankPrefix, '')).toSet();
    final added = t.to.split(',').map((s) => s.trim().replaceFirst(_rankPrefix, '')).where((n) => n.isNotEmpty && !was.contains(n)).toList();
    if (added.isNotEmpty) return '${t.from.isNotEmpty ? 'Замена' : 'Преподаватель'}: ${added.join(', ')}';
  }
  final r = find('rooms');
  if (r != null) return 'Аудитория: ${r.to.isNotEmpty ? r.to : 'не указана'}';
  if (find('subject') != null) return 'Другой предмет';
  return f.isNotEmpty ? 'Изменено' : null;
}

const int _changeFreshMs = 14 * 86400000;

List<LessonChange> freshChanges(GroupPackage pkg, DateTime now) {
  final lc = pkg.lastChange;
  if (lc == null) return const [];
  final published = DateTime.parse(lc.publishedAt).millisecondsSinceEpoch;
  if (now.millisecondsSinceEpoch - published > _changeFreshMs) return const [];
  return lc.changes;
}

String? dayOff(GroupPackage pkg, DateTime date) {
  final cal = pkg.calendar;
  if (cal == null) return null;
  final d = ymd(date);
  for (final h in cal.holidays) {
    if (h.date == d) return h.name;
  }
  Period? p;
  for (final x in cal.periods) {
    if (d.compareTo(x.from) >= 0 && d.compareTo(x.to) <= 0) {
      p = x;
      break;
    }
  }
  return p == null || p.kind == 'study' ? null : periodLabel[p.kind];
}

List<DayLesson> lessonsForDate(GroupPackage pkg, DateTime date, int subgroup, DateTime now) {
  final day = isoDay(date);
  final week = weekTypeFor(date, pkg.semesterStart);
  final bells = bellsForDay(pkg.bells ?? defaultBells, day);
  final changes = freshChanges(pkg, now).where((c) => c.day == day && (c.week == 'BOTH' || c.week == week)).toList();

  final out = <DayLesson>[];
  final base = dayOff(pkg, date) != null ? const <Lesson>[] : pkg.lessons;
  for (final l in base) {
    if (l.day != day || !(l.week == 'BOTH' || l.week == week) || !matchesSubgroup(l.subgroup, subgroup)) continue;
    final bell = _bellByNum(bells, l.num);
    if (bell == null) continue;
    LessonChange? ch;
    for (final c in changes) {
      if (c.num == l.num && c.subject == l.subject && (c.subgroup == 0 || c.subgroup == l.subgroup)) {
        ch = c;
        break;
      }
    }
    out.add(DayLesson(key: '${l.num}-${l.subgroup}-${l.subject}', num: l.num, bell: bell, lesson: l, override: null, overrideNote: null, change: ch != null ? describeChange(ch) : null));
  }

  final dateStr = ymd(date);
  for (final o in pkg.overrides.where((x) => x.date == dateStr && matchesSubgroup(x.subgroup, subgroup))) {
    final bell = _bellByNum(bells, o.num);
    if (o.action != 'cancel' && (o.lesson == null || bell == null)) continue;
    if (o.action != 'add') {
      for (var i = out.length - 1; i >= 0; i--) {
        final current = out[i];
        if (current.num != o.num || !(o.subgroup == 0 || current.lesson.subgroup == 0 || current.lesson.subgroup == o.subgroup)) continue;
        if (subgroup == 0 && o.subgroup != 0 && current.lesson.subgroup == 0) {
          final remaining = o.subgroup == 1 ? 2 : 1;
          out[i] = current.withLesson('${current.key}-sub$remaining', current.lesson.withSubgroup(remaining));
        } else {
          out.removeAt(i);
        }
      }
    }
    if (o.action == 'cancel') continue;
    final lesson = o.subgroup != 0 ? o.lesson!.withSubgroup(o.subgroup) : o.lesson!;
    out.add(DayLesson(key: 'o${o.id}', num: o.num, bell: bell!, lesson: lesson, override: o.action, overrideNote: o.note, change: null));
  }
  final indexed = [for (var i = 0; i < out.length; i++) (i, out[i])];
  indexed.sort((a, b) {
    final byNum = a.$2.num - b.$2.num;
    if (byNum != 0) return byNum;
    final bySub = a.$2.lesson.subgroup - b.$2.lesson.subgroup;
    return bySub != 0 ? bySub : a.$1 - b.$1;
  });
  return [for (final e in indexed) e.$2];
}

Bell? _bellByNum(List<Bell> bells, int num) {
  for (final b in bells) {
    if (b.num == num) return b;
  }
  return null;
}

({DateTime date, List<DayLesson> items})? nextStudyDay(GroupPackage pkg, DateTime from, int subgroup, DateTime now) {
  for (var i = 1; i <= 14; i++) {
    final date = addDays(from, i);
    final items = lessonsForDate(pkg, date, subgroup, now);
    if (items.isNotEmpty) return (date: date, items: items);
  }
  return null;
}

int pairsCount(List<DayLesson> items) => {for (final x in items) x.num}.length;

String? changeChip(DayLesson item) => item.override == 'add' ? 'Доп.' : null;

bool isReplaced(DayLesson item) => item.override == 'replace' || item.change != null;

int? buildingOf(Lesson l) {
  for (final r in l.rooms) {
    if (!r.placeholder && r.building != null) return r.building;
  }
  return null;
}

const _rankWord = {
  'асс.': 'Ассистент',
  'доц.': 'Доцент',
  'проф.': 'Профессор',
  'ст.пр.': 'Старший преподаватель',
  'преп.': 'Преподаватель',
  'зав.каф.': 'Заведующий кафедрой',
};

String rankLabel(String? rank) {
  final key = (rank ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  if (key.isEmpty) return '';
  return _rankWord[key] ?? _rankWord[key.endsWith('.') ? key : '$key.'] ?? (rank ?? '').trim();
}

const weekLabel = {'UPPER': 'Верхняя неделя', 'LOWER': 'Нижняя неделя'};

class CancelledLesson {
  const CancelledLesson({required this.num, required this.bell, required this.subject, required this.note});
  final int num;
  final Bell bell;
  final String subject;
  final String? note;
}

List<CancelledLesson> cancelledForDate(GroupPackage pkg, DateTime date, int subgroup) {
  final day = isoDay(date);
  final week = weekTypeFor(date, pkg.semesterStart);
  final bells = bellsForDay(pkg.bells ?? defaultBells, day);
  final d = ymd(date);
  final out = <CancelledLesson>[];
  for (final o in pkg.overrides) {
    if (o.date != d || o.action != 'cancel' || !matchesSubgroup(o.subgroup, subgroup)) continue;
    Lesson? base;
    for (final l in pkg.lessons) {
      if (l.day == day && l.num == o.num && (l.week == 'BOTH' || l.week == week) && matchesSubgroup(l.subgroup, subgroup) && (o.subgroup == 0 || l.subgroup == 0 || l.subgroup == o.subgroup)) {
        base = l;
        break;
      }
    }
    final bell = _bellByNum(bells, o.num);
    if (bell != null) out.add(CancelledLesson(num: o.num, bell: bell, subject: base?.subject ?? 'Занятие', note: o.note));
  }
  return out;
}

String cancelledKey(int num) => 'x$num';

enum DayRelation { past, today, future }

enum LessonPhase { live, soon, later, upcoming, done, cancelled }

const soonMinutes = 60;

class LessonStatus {
  const LessonStatus({required this.phase, required this.label, required this.replaced, required this.extra, required this.teacherPending, this.minutes, this.progress});
  final LessonPhase phase;
  final String label;
  final int? minutes;
  final double? progress;
  final bool replaced;
  final bool extra;
  final bool teacherPending;
}

String _clock(int minutes) => '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';

LessonStatus lessonStatus({
  required Bell bell,
  required String? override,
  required String? change,
  required bool teacherPending,
  required double minuteOfDay,
  required DayRelation when,
  bool cancelled = false,
}) {
  final replaced = override == 'replace' || change != null;
  final extra = override == 'add';
  LessonStatus make(LessonPhase phase, String label, {int? minutes, double? progress}) =>
      LessonStatus(phase: phase, label: label, replaced: replaced, extra: extra, teacherPending: teacherPending, minutes: minutes, progress: progress);
  final start = bell.startMinutes, end = bell.endMinutes;
  if (cancelled) return make(LessonPhase.cancelled, 'Отменена');
  if (when == DayRelation.past) return make(LessonPhase.done, 'Прошла');
  if (when == DayRelation.future) return make(LessonPhase.upcoming, 'Начало в ${_clock(start)}');
  if (minuteOfDay >= end) return make(LessonPhase.done, 'Прошла');
  if (minuteOfDay >= start) {
    final left = (end - minuteOfDay).ceil();
    return make(LessonPhase.live, 'Идёт · ещё ${formatDuration(left)}', minutes: left, progress: (minuteOfDay - start) / (end - start));
  }
  final until = (start - minuteOfDay).ceil();
  if (until <= soonMinutes) return make(LessonPhase.soon, 'Скоро · через ${formatDuration(until)}', minutes: until);
  return make(LessonPhase.later, 'Позже · в ${_clock(start)}', minutes: until);
}

class Gap {
  const Gap({required this.kind, required this.from, required this.to, required this.minutes, required this.walkTo});
  final String kind;
  final int from;
  final int to;
  final int minutes;
  final int? walkTo;
}

List<Gap?> gapsOf(List<DayLesson> items) {
  return [
    for (var i = 0; i < items.length; i++)
      () {
        if (i + 1 >= items.length || items[i + 1].num == items[i].num) return null;
        final it = items[i], next = items[i + 1];
        final from = it.bell.endMinutes, to = next.bell.startMinutes;
        final a = buildingOf(it.lesson), b = buildingOf(next.lesson);
        return Gap(kind: to - from >= windowMin ? 'window' : 'break', from: from, to: to, minutes: to - from, walkTo: a != null && b != null && a != b ? b : null);
      }(),
  ];
}

sealed class NowState {
  const NowState();
}

class NowBefore extends NowState {
  const NowBefore(this.next, this.minutes);
  final DayLesson next;
  final int minutes;
}

class NowLive extends NowState {
  const NowLive(this.current, this.left, this.progress, this.next);
  final DayLesson current;
  final int left;
  final double progress;
  final DayLesson? next;
}

class NowGap extends NowState {
  const NowGap(this.window, this.next, this.minutes, this.gap);
  final bool window;
  final DayLesson next;
  final int minutes;
  final Gap gap;
}

class NowDone extends NowState {
  const NowDone(this.endedAt);
  final int endedAt;
}

class NowEmpty extends NowState {
  const NowEmpty();
}

NowState nowState(List<DayLesson> items, double minuteOfDay) {
  if (items.isEmpty) return const NowEmpty();
  final gaps = gapsOf(items);
  for (var i = 0; i < items.length; i++) {
    final it = items[i];
    final s = it.bell.startMinutes, e = it.bell.endMinutes;
    if (minuteOfDay < s) {
      final minutes = (s - minuteOfDay).ceil();
      if (i == 0) return NowBefore(it, minutes);
      final gap = gaps[i - 1] ?? Gap(kind: 'break', from: items[i - 1].bell.endMinutes, to: s, minutes: s - items[i - 1].bell.endMinutes, walkTo: null);
      return NowGap(gap.kind == 'window', it, minutes, gap);
    }
    if (minuteOfDay < e) {
      DayLesson? next;
      for (final x in items.skip(i + 1)) {
        if (x.num != it.num) {
          next = x;
          break;
        }
      }
      return NowLive(it, (e - minuteOfDay).ceil(), (minuteOfDay - s) / (e - s), next);
    }
  }
  return NowDone(items.map((x) => x.bell.endMinutes).reduce((a, b) => a > b ? a : b));
}

List<int> weekCounts(GroupPackage pkg, DateTime anyDateInWeek, int subgroup) {
  final monday = addDays(anyDateInWeek, -(isoDay(anyDateInWeek) - 1));
  return [for (var i = 0; i < 7; i++) {for (final x in lessonsForDate(pkg, addDays(monday, i), subgroup, addDays(monday, i))) x.num}.length];
}
