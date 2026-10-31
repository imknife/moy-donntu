import 'models.dart';
import 'time_utils.dart';

const periodName = {'study': 'Учёба', 'credits': 'Зачётная неделя', 'exams': 'Сессия', 'break': 'Каникулы'};

int _dayIndex(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

int _index(String ymdString) {
  final d = parseYmd(ymdString);
  return d == null ? -1 << 40 : _dayIndex(d);
}

Period? currentPeriod(AcademicCalendar? calendar, DateTime date) {
  final today = _dayIndex(date);
  for (final p in calendar?.periods ?? const <Period>[]) {
    if (_index(p.from) <= today && today <= _index(p.to)) return p;
  }
  return null;
}

sealed class SessionStatus {
  const SessionStatus();
}

class SessionNone extends SessionStatus {
  const SessionNone();
}

class SessionAhead extends SessionStatus {
  const SessionAhead(this.days, this.period);
  final int days;
  final Period period;
}

class SessionRunning extends SessionStatus {
  const SessionRunning(this.daysLeft, this.period);
  final int daysLeft;
  final Period period;
}

class SessionOver extends SessionStatus {
  const SessionOver();
}

SessionStatus sessionStatus(AcademicCalendar? calendar, DateTime date) {
  final exams = [for (final p in calendar?.periods ?? const <Period>[]) if (p.kind == 'exams') p]..sort((a, b) => _index(a.from) - _index(b.from));
  if (exams.isEmpty) return const SessionNone();
  final today = _dayIndex(date);
  Period? period;
  for (final item in exams) {
    if (_index(item.to) >= today) {
      period = item;
      break;
    }
  }
  if (period == null) return const SessionOver();
  return _index(period.from) > today ? SessionAhead(_index(period.from) - today, period) : SessionRunning(_index(period.to) - today, period);
}

List<TimeSpan> commonWindows(List<Bell> bells, List<TimeSpan> busyA, List<TimeSpan> busyB, {int min = 30}) {
  if (bells.isEmpty) return const [];
  final dayStart = bells.first.startMinutes, dayEnd = bells.last.endMinutes;
  final busy = [
    for (final i in [...busyA, ...busyB])
      if (_min(i.to, dayEnd) > _max(dayStart, i.from)) TimeSpan(_max(dayStart, i.from), _min(dayEnd, i.to)),
  ]..sort((a, b) => a.from - b.from);
  final free = <TimeSpan>[];
  var cursor = dayStart;
  for (final item in busy) {
    if (item.from > cursor) free.add(TimeSpan(cursor, item.from));
    cursor = _max(cursor, item.to);
  }
  if (dayEnd > cursor) free.add(TimeSpan(cursor, dayEnd));
  return free.where((i) => i.to - i.from >= min).toList();
}

int _min(int a, int b) => a < b ? a : b;
int _max(int a, int b) => a > b ? a : b;

({String kind, int num})? bellState(List<Bell> bells, int minute) {
  for (final bell in bells) {
    if (minute >= bell.startMinutes && minute < bell.endMinutes) return (kind: 'pair', num: bell.num);
    if (minute < bell.startMinutes) return identical(bell, bells.first) ? null : (kind: 'break', num: bell.num);
  }
  return null;
}

String pluralDays(int n) => '$n ${n % 10 == 1 && n % 100 != 11 ? 'день' : ([2, 3, 4].contains(n % 10) && ![12, 13, 14].contains(n % 100)) ? 'дня' : 'дней'}';

String humanDate(String value) {
  final date = parseYmd(value);
  return date == null ? value : '${dayShort[isoDay(date)]}, ${formatDayDate(date)}';
}

String greeting(int hour) => hour < 6 ? 'Доброй ночи' : hour < 12 ? 'Доброе утро' : hour < 18 ? 'Добрый день' : 'Добрый вечер';

String firstName(String name) => name.trim().split(RegExp(r'\s+')).first;

String displayFromFullName(String full) {
  final parts = full.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  return parts.length >= 2 ? '${parts[1]} ${parts[0]}' : (parts.isNotEmpty ? parts[0] : '');
}
