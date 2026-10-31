import 'ace.dart';
import 'time_utils.dart';

({String dis, String? date})? absenceOf(AceFeedItem item) {
  if (item.kind != 'absence') return null;
  final m = RegExp(r'пропуск по дисциплине\s*["«]([^"»]+)["»](?:\s*за\s*(\d{2}\.\d{2}\.\d{4}))?', caseSensitive: false).firstMatch(item.text);
  return m != null ? (dis: m[1]!.trim(), date: m[2] ?? item.date) : (dis: item.text, date: item.date);
}

const feedFilters = ['Все', 'Пропуски', 'Оценки', 'Приказы'];

List<AceFeedItem> filterFeed(List<AceFeedItem> items, String filter) {
  final kind = switch (filter) { 'Пропуски' => 'absence', 'Оценки' => 'grade', 'Приказы' => 'move', _ => null };
  return kind != null ? [for (final i in items) if (i.kind == kind) i] : items;
}

String feedSummary(int absences, int unread) {
  final parts = <String>[
    if (absences > 0) '$absences ${plural(absences, 'пропуск', 'пропуска', 'пропусков')}',
    if (unread > 0) '$unread ${plural(unread, 'новое', 'новых', 'новых')}',
  ];
  return parts.isEmpty ? 'Нет новых' : parts.join(' · ');
}

String plainText(String html) => html
    .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&quot;', '"')
    .replaceAll('&amp;', '&')
    .trim();
