import 'models.dart';

const int mskOffsetMin = 180;

DateTime toMsk(DateTime instant) => instant.toUtc().add(const Duration(minutes: mskOffsetMin));

DateTime dateOf(int y, int m, int d) => DateTime.utc(y, m, d);

DateTime startOfDay(DateTime d) => DateTime.utc(d.year, d.month, d.day);

DateTime addDays(DateTime d, int n) => DateTime.utc(d.year, d.month, d.day + n);

int isoDay(DateTime d) => d.weekday;

DateTime startOfIsoWeek(DateTime d) => addDays(d, -(isoDay(d) - 1));

DateTime? parseYmd(String s) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
  return m == null ? null : DateTime.utc(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
}

String ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

int daysBetween(DateTime a, DateTime b) => DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

int toMinutes(String hm) {
  final p = hm.split(':');
  return (int.tryParse(p[0]) ?? 0) * 60 + (p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
}

String shortTime(String hm) => hm.replaceFirstMapped(RegExp(r'^0(\d):'), (m) => '${m[1]}:');

String minutesToTime(int min) => '${min ~/ 60}:${(min % 60).toString().padLeft(2, '0')}';

List<Bell> _grid(List<List<String>> pairs) => [
      for (var i = 0; i < pairs.length; i++)
        Bell(num: i + 1, start: pairs[i][0], end: pairs[i][1], startMinutes: toMinutes(pairs[i][0]), endMinutes: toMinutes(pairs[i][1])),
    ];

final BellGrids defaultBells = BellGrids(
  weekday: _grid([
    ['08:00', '09:35'], ['09:55', '11:30'], ['11:50', '13:25'], ['13:45', '15:20'],
    ['15:30', '17:05'], ['17:15', '18:50'], ['19:00', '20:35'],
  ]),
  weekend: _grid([
    ['08:00', '09:35'], ['09:45', '11:20'], ['11:40', '13:15'], ['13:25', '15:00'],
    ['15:10', '16:45'], ['16:55', '18:30'], ['18:40', '20:15'],
  ]),
);

List<Bell> bellsForDay(BellGrids bells, int day) => day >= 6 ? bells.weekend : bells.weekday;

const dayNames = ['', 'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
const dayShort = ['', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
const monthsGenitive = [
  'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
  'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
];
const monthsShort = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
const monthsNominative = [
  'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
  'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
];

const int _weekMs = 7 * 86400000;

String weekTypeFor(DateTime date, String? semesterStart) {
  final start = (semesterStart != null ? parseYmd(semesterStart) : null) ?? DateTime.utc(date.year, 9, 1);
  final weeks = (startOfIsoWeek(date).difference(startOfIsoWeek(start)).inMilliseconds / _weekMs).round();
  return weeks.abs() % 2 == 0 ? 'UPPER' : 'LOWER';
}

String formatDayDate(DateTime d) => '${d.day} ${monthsGenitive[d.month - 1]}';

String plural(int count, String one, String few, String many) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}

String pluralLessons(int count) => '$count ${plural(count, 'пара', 'пары', 'пар')}';

String formatDuration(int minutes) {
  if (minutes < 60) return '$minutes мин';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h ч' : '$h ч $m мин';
}
