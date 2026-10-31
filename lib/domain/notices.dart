import 'cabinet_feed.dart';
import 'deadline.dart';
import 'models.dart';
import 'time_utils.dart';

class Notice {
  const Notice({required this.id, required this.icon, required this.title, required this.text, required this.route});
  final String id;
  final String icon;
  final String title;
  final String text;
  final String route;
}

(String, String) changeVerb(LessonChange change) {
  if (change.type == 'added') return ('добавлена', '');
  if (change.type == 'removed') return ('отменена', '');
  for (final f in change.fields ?? const <FieldChange>[]) {
    if (f.field == 'rooms') return ('перенесена', f.to.isNotEmpty ? ' в ${f.to}' : '');
    if (f.field == 'teachers') return ('новый преподаватель', '');
    if (f.field == 'subject') return ('другой предмет', '');
  }
  return ('изменена', '');
}

String _fieldsKey(LessonChange change) {
  final parts = [
    for (final f in change.fields ?? const <FieldChange>[]) f.from.isEmpty ? '${f.field}:${f.to}' : '${f.field}:${f.from}>${f.to}',
  ]..sort();
  return parts.isEmpty ? '' : ':${parts.join('|')}';
}

List<Notice> buildNotices({
  required List<LessonChange> changes,
  required List<Deadline> deadlines,
  required DateTime today,
  required int minute,
  int feedAbsences = 0,
  int feedUnread = 0,
}) {
  final notices = <Notice>[];
  for (final change in changes) {
    final (verb, tail) = changeVerb(change);
    notices.add(Notice(
      id: 'change:${change.day}:${change.num}:${change.week}:${change.subgroup}:${change.type}:${change.subject}${_fieldsKey(change)}',
      icon: 'changes',
      title: change.subject,
      text: '${dayShort[change.day]} · $verb$tail',
      route: 'changes',
    ));
  }
  for (final d in deadlines) {
    final bucket = deadlineBucket(d, today, minute);
    if (bucket != DeadlineBucket.overdue && bucket != DeadlineBucket.today) continue;
    notices.add(Notice(
      id: '${bucket.name}:${d.id}:${d.due}',
      icon: 'deadline',
      title: d.title,
      text: bucket == DeadlineBucket.overdue ? deadlineWhen(d, today, minute) : 'Срок сегодня',
      route: 'deadlines',
    ));
  }
  if (feedAbsences > 0 || feedUnread > 0) {
    notices.add(Notice(id: 'feed:$feedAbsences:$feedUnread', icon: 'bell', title: 'Лента кабинета', text: feedSummary(feedAbsences, feedUnread), route: 'cabinet'));
  }
  return notices;
}
