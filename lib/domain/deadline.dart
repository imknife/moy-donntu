import 'time_utils.dart';

enum DeadlineBucket { overdue, today, soon, later, done }

const deadlineBucketTitles = {
  DeadlineBucket.overdue: 'Просрочено',
  DeadlineBucket.today: 'Сегодня',
  DeadlineBucket.soon: 'На этой неделе',
  DeadlineBucket.later: 'Позже',
  DeadlineBucket.done: 'Выполнено',
};

class Deadline {
  const Deadline({
    required this.id,
    required this.title,
    required this.due,
    required this.createdAt,
    this.time,
    this.subject,
    this.lessonKey,
    this.lessonDate,
    this.kind,
    this.details = '',
    this.done = false,
    this.remindMinutes,
  });
  final String id;
  final String title;
  final String due;
  final String createdAt;
  final String? time;
  final String? subject;
  final String? lessonKey;
  final String? lessonDate;
  final String? kind;
  final String details;
  final bool done;
  final int? remindMinutes;

  factory Deadline.fromJson(Map<String, dynamic> j) => Deadline(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        due: j['due'] as String? ?? '',
        createdAt: j['createdAt'] as String? ?? '',
        time: j['time'] as String?,
        subject: j['subject'] as String?,
        lessonKey: j['lessonKey'] as String?,
        lessonDate: j['lessonDate'] as String?,
        kind: j['kind'] as String?,
        details: j['details'] as String? ?? '',
        done: j['done'] as bool? ?? false,
        remindMinutes: (j['remindMinutes'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'due': due,
        'createdAt': createdAt,
        if (time != null) 'time': time,
        if (subject != null) 'subject': subject,
        if (lessonKey != null) 'lessonKey': lessonKey,
        if (lessonDate != null) 'lessonDate': lessonDate,
        if (kind != null) 'kind': kind,
        if (details.isNotEmpty) 'details': details,
        if (done) 'done': true,
        if (remindMinutes != null) 'remindMinutes': remindMinutes,
      };

  Deadline copyWith({String? title, String? due, String? time, bool clearTime = false, String? subject, bool clearSubject = false, String? details, bool? done, int? remindMinutes, bool clearRemind = false}) => Deadline(
        id: id,
        title: title ?? this.title,
        due: due ?? this.due,
        createdAt: createdAt,
        time: clearTime ? null : (time ?? this.time),
        subject: clearSubject ? null : (subject ?? this.subject),
        lessonKey: clearSubject ? null : lessonKey,
        lessonDate: clearSubject ? null : lessonDate,
        kind: clearSubject ? null : kind,
        details: details ?? this.details,
        done: done ?? this.done,
        remindMinutes: clearRemind ? null : (remindMinutes ?? this.remindMinutes),
      );

  DateTime? get dueDate => parseYmd(due);

  int get dueMinute => time == null ? 24 * 60 - 1 : toMinutes(time!);
}

int deadlineOrder(Deadline a, Deadline b) {
  final byDate = a.due.compareTo(b.due);
  if (byDate != 0) return byDate;
  final byTime = a.dueMinute - b.dueMinute;
  if (byTime != 0) return byTime;
  return a.createdAt.compareTo(b.createdAt);
}

DeadlineBucket deadlineBucket(Deadline d, DateTime today, int minute) {
  if (d.done) return DeadlineBucket.done;
  final due = d.dueDate;
  if (due == null) return DeadlineBucket.later;
  final days = daysBetween(today, due);
  if (days < 0) return DeadlineBucket.overdue;
  if (days == 0) return d.time != null && d.dueMinute < minute ? DeadlineBucket.overdue : DeadlineBucket.today;
  if (days <= 7) return DeadlineBucket.soon;
  return DeadlineBucket.later;
}

String deadlineWhen(Deadline d, DateTime today, int minute) {
  final due = d.dueDate;
  if (due == null) return '';
  final days = daysBetween(today, due);
  final time = d.time == null ? '' : ', ${shortTime(d.time!)}';
  if (d.done) return '${formatDayDate(due)}$time';
  if (days < -1) return 'Просрочено на ${-days} ${plural(-days, 'день', 'дня', 'дней')}';
  if (days == -1) return 'Просрочено со вчера';
  if (days == 0) return d.time != null && d.dueMinute < minute ? 'Просрочено сегодня в ${shortTime(d.time!)}' : 'Сегодня$time';
  if (days == 1) return 'Завтра$time';
  if (days < 7) return '${dayShort[isoDay(due)]}, ${formatDayDate(due)}$time';
  return '${formatDayDate(due)}$time';
}

Map<DeadlineBucket, List<Deadline>> groupDeadlines(List<Deadline> list, DateTime today, int minute) {
  final out = {for (final b in DeadlineBucket.values) b: <Deadline>[]};
  for (final d in list) {
    out[deadlineBucket(d, today, minute)]!.add(d);
  }
  for (final b in DeadlineBucket.values) {
    out[b]!.sort(b == DeadlineBucket.done ? (a, c) => deadlineOrder(c, a) : deadlineOrder);
  }
  return out;
}

int openDeadlines(List<Deadline> list) => list.where((d) => !d.done).length;

int overdueDeadlines(List<Deadline> list, DateTime today, int minute) => list.where((d) => deadlineBucket(d, today, minute) == DeadlineBucket.overdue).length;

Deadline? nextDeadline(List<Deadline> list, DateTime today, int minute) {
  final open = list.where((d) => !d.done && deadlineBucket(d, today, minute) != DeadlineBucket.overdue).toList()..sort(deadlineOrder);
  return open.isEmpty ? null : open.first;
}

List<Deadline> deadlinesForLesson(List<Deadline> list, String? key, String date) {
  if (key == null) return const [];
  final out = list.where((d) => d.lessonKey == key && (d.lessonDate == null || d.lessonDate == date)).toList()..sort(deadlineOrder);
  return out;
}
