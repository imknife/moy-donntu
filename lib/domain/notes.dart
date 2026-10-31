import 'collate.dart';

const todoMark = '☐ ';
const doneMark = '☑ ';

class Note {
  const Note({
    required this.id,
    required this.title,
    required this.text,
    required this.updatedAt,
    this.lessonKey,
    this.lessonDate,
    this.subject,
    this.kind,
    this.pinned = false,
  });
  final String id;
  final String title;
  final String text;
  final String updatedAt;
  final String? lessonKey;
  final String? lessonDate;
  final String? subject;
  final String? kind;
  final bool pinned;

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        text: j['text'] as String? ?? '',
        updatedAt: j['updatedAt'] as String? ?? '',
        lessonKey: j['lessonKey'] as String?,
        lessonDate: j['lessonDate'] as String?,
        subject: j['subject'] as String?,
        kind: j['kind'] as String?,
        pinned: j['pinned'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'text': text,
        'updatedAt': updatedAt,
        if (lessonKey != null) 'lessonKey': lessonKey,
        if (lessonDate != null) 'lessonDate': lessonDate,
        if (subject != null) 'subject': subject,
        if (kind != null) 'kind': kind,
        if (pinned) 'pinned': true,
      };

  Note copyWith({String? title, String? text, String? updatedAt}) => Note(
        id: id,
        title: title ?? this.title,
        text: text ?? this.text,
        updatedAt: updatedAt ?? this.updatedAt,
        lessonKey: lessonKey,
        lessonDate: lessonDate,
        subject: subject,
        kind: kind,
        pinned: pinned,
      );
}

int _stamp(Note n) => DateTime.tryParse(n.updatedAt)?.millisecondsSinceEpoch ?? 0;

List<Note> notesForLesson(List<Note> notes, String? key, String date) {
  if (key == null) return const [];
  final out = notes.where((n) => n.lessonKey == key && (n.lessonDate == null || n.lessonDate == date)).toList();
  out.sort((a, b) => _stamp(b) - _stamp(a));
  return out;
}

class NoteLine {
  const NoteLine({required this.index, required this.isTodo, required this.checked, required this.text});
  final int index;
  final bool isTodo;
  final bool checked;
  final String text;
}

List<NoteLine> parseLines(String text) {
  final lines = text.split('\n');
  return [
    for (var i = 0; i < lines.length; i++)
      if (lines[i].startsWith(todoMark))
        NoteLine(index: i, isTodo: true, checked: false, text: lines[i].substring(2))
      else if (lines[i].startsWith(doneMark))
        NoteLine(index: i, isTodo: true, checked: true, text: lines[i].substring(2))
      else
        NoteLine(index: i, isTodo: false, checked: false, text: lines[i]),
  ];
}

String toggleLine(String text, int index) {
  final lines = text.split('\n');
  if (index < 0 || index >= lines.length) return text;
  final line = lines[index];
  if (line.startsWith(todoMark)) {
    lines[index] = doneMark + line.substring(2);
  } else if (line.startsWith(doneMark)) {
    lines[index] = todoMark + line.substring(2);
  }
  return lines.join('\n');
}

({int done, int total}) progress(String text) {
  final todo = parseLines(text).where((l) => l.isTodo).toList();
  return (done: todo.where((l) => l.checked).length, total: todo.length);
}

String addChecklistItem(String text) {
  if (text.isEmpty) return todoMark;
  if (text.endsWith('\n')) return text + todoMark;
  return '$text\n$todoMark';
}

String autoContinue(String prev, String next) {
  if (next != '$prev\n') return next;
  final last = prev.substring(prev.lastIndexOf('\n') + 1);
  if (last == todoMark || last == doneMark) return prev.substring(0, prev.length - last.length);
  return last.startsWith(todoMark) || last.startsWith(doneMark) ? next + todoMark : next;
}

String _clean(String line) => line.replaceFirst(RegExp(r'^[☐☑]\s?'), '').trim();

String noteTitle(Note note) {
  final own = note.title.trim();
  if (own.isNotEmpty) return own;
  for (final l in note.text.split('\n')) {
    final c = _clean(l);
    if (c.isNotEmpty) return c.length > 80 ? c.substring(0, 80) : c;
  }
  return 'Заметка';
}

String noteMarker(List<Note> notes) {
  var done = 0, total = 0;
  for (final n in notes) {
    final p = progress(n.text);
    done += p.done;
    total += p.total;
  }
  if (total > 0) return 'Чеклист $done/$total';
  return notes.length > 1 ? 'Заметки · ${notes.length}' : 'Заметка';
}

const noteFilters = ['Все', 'К парам', 'Свои'];

const _noteMonths = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];

List<Note> filterNotes(List<Note> notes, String filter, String query) {
  final q = query.trim().toLowerCase();
  return [
    for (final n in notes)
      if ((filter == 'Все' || (filter == 'К парам') == (n.lessonKey != null && n.lessonKey!.isNotEmpty)) && (q.isEmpty || '${n.title} ${n.text} ${n.subject ?? ''}'.toLowerCase().contains(q))) n,
  ];
}

sealed class NoteRow {
  const NoteRow(this.key);
  final String key;
}

class NoteHeaderRow extends NoteRow {
  const NoteHeaderRow(super.key, this.title);
  final String title;
}

class NoteItemRow extends NoteRow {
  const NoteItemRow(super.key, this.note);
  final Note note;
}

int _mskMidnightMs(DateTime msk) => DateTime.utc(msk.year, msk.month, msk.day).millisecondsSinceEpoch - 180 * 60000;

List<NoteRow> buildNoteRows(List<Note> notes, DateTime nowMsk) {
  final today = _mskMidnightMs(nowMsk);
  final monday = today - (nowMsk.weekday - 1) * 86400000;
  final groups = <(String, List<Note>)>[('Закреплённые', []), ('Сегодня', []), ('На этой неделе', []), ('Раньше', [])];
  final sorted = stableSorted(notes, (a, b) => _stamp(b) - _stamp(a));
  for (final note in sorted) {
    final t = _stamp(note);
    groups[note.pinned ? 0 : t >= today ? 1 : t >= monday ? 2 : 3].$2.add(note);
  }
  return [
    for (final g in groups)
      if (g.$2.isNotEmpty) ...[NoteHeaderRow('h:${g.$1}', g.$1), for (final n in g.$2) NoteItemRow(n.id, n)],
  ];
}

String noteDateLabel(String iso, DateTime nowMsk) {
  final t = DateTime.tryParse(iso);
  if (t == null) return '';
  final d = t.toUtc().add(const Duration(minutes: 180));
  final days = ((_mskMidnightMs(nowMsk) - _mskMidnightMs(d)) / 86400000).round();
  String pad(int n) => n.toString().padLeft(2, '0');
  if (days == 0) return '${pad(d.hour)}:${pad(d.minute)}';
  if (days == 1) return 'Вчера';
  return '${d.day} ${_noteMonths[d.month - 1]}${d.year == nowMsk.year ? '' : ' ${d.year}'}';
}

const _kindTags = {'lecture': 'ЛЕК', 'practice': 'ПР', 'lab': 'ЛАБ', 'exam': 'ЭКЗ', 'credit': 'ЗАЧ', 'consultation': 'КОНС', 'coursework': 'КР'};

String noteKindTag(String? kind) => kind == null ? '' : (_kindTags[kind] ?? '');

List<Note> topNotes(List<Note> notes, int count) {
  final sorted = stableSorted(notes, (a, b) {
    final byPin = (b.pinned ? 1 : 0) - (a.pinned ? 1 : 0);
    return byPin != 0 ? byPin : _stamp(b) - _stamp(a);
  });
  return sorted.take(count).toList();
}

String notePreview(Note note) {
  final lines = note.text.split('\n');
  final own = note.title.trim().isNotEmpty;
  final skip = own ? 0 : lines.indexWhere((l) => _clean(l).isNotEmpty);
  final start = skip < 0 ? 0 : skip + (own ? 0 : 1);
  final joined = lines.skip(start).map(_clean).where((l) => l.isNotEmpty).join(' · ');
  return joined.length > 160 ? joined.substring(0, 160) : joined;
}
