import 'dart:convert';

import 'collate.dart';
import 'directory.dart';
import 'models.dart';
import 'schedule.dart';
import 'time_utils.dart';

class RoomLessonGroup {
  RoomLessonGroup(this.id, this.item);
  final String id;
  final DayLesson item;
  final List<RoomDayLesson> sources = [];
  bool conflict = false;
}

String _sortedPairs(Iterable<List<Object?>> rows) {
  final encoded = rows.map((r) => r.join(',')).toList()..sort();
  return jsonEncode(encoded);
}

List<RoomLessonGroup> groupRoomLessons(List<RoomDayLesson> rows) {
  final groups = <String, RoomLessonGroup>{};
  for (final source in rows) {
    final item = source.item;
    final lesson = item.lesson;
    final id = jsonEncode([
      item.bell.startMinutes,
      item.bell.endMinutes,
      item.num,
      lesson.subject,
      lesson.kind,
      lesson.subgroup,
      _sortedPairs(lesson.teachers.map((t) => [t.name, t.rank])),
      lesson.teacherPending,
      _sortedPairs(lesson.rooms.map((r) => [r.label, r.building, r.floor, r.placeholder])),
      item.override,
      item.overrideNote,
      item.change,
    ]);
    final grouped = groups.putIfAbsent(id, () => RoomLessonGroup(id, item));
    if (!grouped.sources.any((s) => s.group == source.group && s.item.key == item.key)) grouped.sources.add(source);
  }
  final result = stableSorted(groups.values, (a, b) => a.item.bell.startMinutes - b.item.bell.startMinutes);
  for (final row in result) {
    row.conflict = result.any((other) => !identical(other, row) && row.item.bell.startMinutes < other.item.bell.endMinutes && other.item.bell.startMinutes < row.item.bell.endMinutes);
  }
  return result;
}

List<int> roomHourTicks(int from, int to) {
  final ticks = [from];
  for (var minute = (from ~/ 60) * 60 + 60; minute < to; minute += 60) {
    ticks.add(minute);
  }
  if (to > from) ticks.add(to);
  return ticks;
}

class RoomSlot {
  RoomSlot(this.bell, this.rows);
  final Bell bell;
  final List<RoomLessonGroup> rows;
}

List<RoomSlot> roomSlots(List<Bell> bells, List<RoomLessonGroup> grouped) {
  final slots = [
    for (final bell in bells) RoomSlot(bell, [for (final row in grouped) if (row.item.bell.startMinutes < bell.endMinutes && row.item.bell.endMinutes > bell.startMinutes) row]),
  ];
  for (final row in grouped) {
    if (!slots.any((s) => s.rows.contains(row))) slots.add(RoomSlot(row.item.bell, [row]));
  }
  return stableSorted(slots, (a, b) => a.bell.startMinutes - b.bell.startMinutes);
}

({bool busy, int? until}) roomStatus(List<TimeSpan> busy, int minute) {
  for (final v in busy) {
    if (v.from <= minute && v.to > minute) return (busy: true, until: v.to);
  }
  for (final v in busy) {
    if (v.from > minute) return (busy: false, until: v.from);
  }
  return (busy: false, until: null);
}

sealed class RoomAgendaItem {
  const RoomAgendaItem();
}

class AgendaBusy extends RoomAgendaItem {
  const AgendaBusy(this.bell, this.row);
  final Bell bell;
  final RoomLessonGroup row;
}

class AgendaFree extends RoomAgendaItem {
  const AgendaFree(this.from, this.to, this.toEnd);
  final String from;
  final String to;
  final bool toEnd;
}

List<RoomAgendaItem> roomAgenda(List<RoomSlot> slots) {
  final items = <RoomAgendaItem>[];
  var run = <RoomSlot>[];
  void flush(bool toEnd) {
    if (run.isNotEmpty) items.add(AgendaFree(run.first.bell.start, run.last.bell.end, toEnd));
    run = [];
  }

  for (final slot in slots) {
    if (slot.rows.isEmpty) {
      run.add(slot);
      continue;
    }
    flush(false);
    for (final row in slot.rows) {
      items.add(AgendaBusy(slot.bell, row));
    }
  }
  flush(true);
  return items;
}

String? cabinetOf(String? room, int? floor) {
  if (room == null || room.isEmpty || floor == null) return null;
  final rest = room.startsWith('$floor') ? room.substring('$floor'.length) : room;
  final cabinet = rest.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  return cabinet.isNotEmpty && cabinet != room ? cabinet : null;
}

int snapToBell(int minute, int isoDayNumber) {
  final edges = [for (final b in bellsForDay(defaultBells, isoDayNumber)) ...[b.startMinutes, b.endMinutes]]..sort();
  var snapped = 0;
  for (final edge in edges) {
    if (edge <= minute) snapped = edge;
  }
  return snapped;
}
