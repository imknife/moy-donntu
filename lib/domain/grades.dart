import 'ace.dart';

enum GradeTone { good, ok, bad, credit, none }

class GradeBadgeModel {
  const GradeBadgeModel(this.tone, this.value, this.word);
  final GradeTone tone;
  final String value;
  final String word;
}

const _words = {5: 'Отлично', 4: 'Хорошо', 3: 'Удовлетворительно', 2: 'Неудовлетворительно'};

bool hasGrade(ZachRow row) => row.markNumber != null && row.markNumber! >= 2 && row.markNumber! <= 5;

bool isCreditRow(ZachRow row) => !hasGrade(row) && (RegExp(r'зач[её]т', caseSensitive: false).hasMatch(row.controlForm) || RegExp(r'зач[её]т', caseSensitive: false).hasMatch(row.mark));

GradeBadgeModel gradeBadge(ZachRow row) {
  final mark = row.mark.trim();
  if (hasGrade(row)) {
    final n = row.markNumber!;
    return GradeBadgeModel(n >= 4 ? GradeTone.good : (n == 3 ? GradeTone.ok : GradeTone.bad), '$n', _words[n] ?? (mark.isNotEmpty ? mark : 'Оценка'));
  }
  if (RegExp(r'не\s*зач', caseSensitive: false).hasMatch(mark)) return const GradeBadgeModel(GradeTone.bad, '–', 'Не зачтено');
  if (mark.isNotEmpty) return GradeBadgeModel(GradeTone.credit, '✓', mark[0].toUpperCase() + mark.substring(1));
  return const GradeBadgeModel(GradeTone.none, '–', 'Не выставлено');
}

String examDate(String? value) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value ?? '');
  return m != null ? '${m[3]}.${m[2]}.${m[1]}' : (value ?? '');
}

String _normal(String text) => text.toLowerCase().replaceAll(RegExp(r'[^а-яёa-z0-9]+'), ' ').trim();

List<ZachRow> rowsForSubject(ZachBook? book, String subject) {
  final target = _normal(subject);
  if (book == null || target.isEmpty) return const [];
  final rows = [
    for (final row in book.rows)
      if (_normal(row.dis) == target || _normal(row.dis).contains(target) || target.contains(_normal(row.dis))) row,
  ];
  return _bySemDesc(rows);
}

List<ZachRow> rowsOfDiscipline(ZachBook? book, String name, [int? sem]) {
  final target = _normal(name);
  if (book == null || target.isEmpty) return const [];
  return _bySemDesc([
    for (final row in book.rows)
      if (_normal(row.dis) == target && (sem == null || row.sem == sem)) row,
  ]);
}

List<ZachRow> _bySemDesc(List<ZachRow> rows) {
  final indexed = [for (final e in rows.indexed) e];
  indexed.sort((a, b) {
    final c = b.$2.sem - a.$2.sem;
    return c != 0 ? c : a.$1 - b.$1;
  });
  return [for (final e in indexed) e.$2];
}

class SemesterStat {
  const SemesterStat(this.sem, this.avg, this.marks, this.credits);
  final int sem;
  final double? avg;
  final int marks;
  final int credits;
}

List<SemesterStat> semesterStats(ZachBook? book) {
  final rows = book?.rows ?? const <ZachRow>[];
  final sems = {for (final r in rows) r.sem}.toList()..sort();
  return [
    for (final sem in sems)
      () {
        final inSem = rows.where((r) => r.sem == sem).toList();
        final marked = inSem.where(hasGrade).toList();
        final avg = marked.isEmpty ? null : marked.fold<int>(0, (s, r) => s + r.markNumber!) / marked.length;
        return SemesterStat(sem, avg, marked.length, inSem.where(isCreditRow).length);
      }(),
  ];
}

String decimalComma(num? value, [int digits = 2]) {
  if (value == null) return '—';
  final rounded = double.parse(value.toStringAsFixed(digits));
  var text = rounded == rounded.truncateToDouble() ? '${rounded.toInt()}' : '$rounded';
  text = text.replaceAll('.', ',');
  return text;
}

String examDay(String? value) {
  final full = examDate(value);
  return RegExp(r'^\d{2}\.\d{2}\.\d{4}$').hasMatch(full) ? full.substring(0, 5) : full;
}

bool isCourseWork(ZachRow row) => RegExp(r'курсов', caseSensitive: false).hasMatch(row.controlForm);

List<(ZachRow, List<ZachRow>)> groupCourseWork(List<ZachRow> rows) {
  final groups = <(ZachRow, List<ZachRow>)>[
    for (final row in rows)
      if (!isCourseWork(row)) (row, <ZachRow>[]),
  ];
  for (final row in rows.where(isCourseWork)) {
    final index = groups.indexWhere((g) => g.$1.sem == row.sem && _normal(g.$1.dis) == _normal(row.dis));
    if (index >= 0) {
      groups[index].$2.add(row);
    } else {
      groups.add((row, <ZachRow>[]));
    }
  }
  return groups;
}

String volumeLabel(ZachRow row) {
  final zet = row.zet != null && row.zet! > 0 ? '${_num(row.zet!)} з.е.' : '';
  final hours = row.hours != null && row.hours! > 0 ? '${_num(row.hours!)} ч' : '';
  return zet.isNotEmpty ? zet : hours;
}

String gradeMeta(ZachRow row, {bool showSem = false, List<ZachRow> extras = const []}) {
  return [
    row.controlForm,
    volumeLabel(row),
    row.dateExam != null && row.dateExam!.isNotEmpty ? examDay(row.dateExam) : '',
    showSem ? '${row.sem} сем.' : '',
    for (final extra in extras) '${extra.controlForm.toLowerCase()} ${extra.markNumber ?? gradeBadge(extra).word.toLowerCase()}',
  ].where((e) => e.isNotEmpty).join(' · ');
}

String _num(num v) => v == v.truncate() ? '${v.toInt()}' : '$v';

String num2(num v) => _num(v);
