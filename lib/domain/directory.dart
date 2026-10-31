import 'dart:convert';

import 'collate.dart';
import 'models.dart';
import 'schedule.dart';
import 'time_utils.dart';

class SharedLesson {
  SharedLesson({required this.day, required this.num, required this.week, required this.subgroup, required this.subject, required this.kind, required this.rooms, required this.teachers, required this.groups});
  final int day;
  final int num;
  final String week;
  final int subgroup;
  final String subject;
  final String kind;
  final List<String> rooms;
  final List<String> teachers;
  final List<String> groups;

  factory SharedLesson.fromJson(Map<String, dynamic> j) => SharedLesson(
        day: j['day'] as int,
        num: j['num'] as int,
        week: j['week'] as String,
        subgroup: j['subgroup'] as int,
        subject: j['subject'] as String,
        kind: j['kind'] as String,
        rooms: [for (final r in (j['rooms'] as List? ?? const [])) r as String],
        teachers: [for (final t in (j['teachers'] as List? ?? const [])) t as String],
        groups: [for (final g in (j['groups'] as List? ?? const [])) g as String],
      );
}

class TeacherHit {
  const TeacherHit(this.name, this.rank, this.lessons);
  final String name;
  final String rank;
  final int lessons;

  factory TeacherHit.fromJson(Map<String, dynamic> j) => TeacherHit(j['name'] as String, j['rank'] as String? ?? '', j['lessons'] as int? ?? 0);
}

class FreeRoom {
  const FreeRoom({required this.label, required this.building, required this.floor, this.freeUntil});
  final String label;
  final int building;
  final int? floor;
  final int? freeUntil;

  factory FreeRoom.fromJson(Map<String, dynamic> j) => FreeRoom(
        label: j['label'] as String,
        building: j['building'] as int,
        floor: j['floor'] as int?,
        freeUntil: j['freeUntil'] as int?,
      );
}

class FreeRooms {
  const FreeRooms(this.free, this.basedOnGroups);
  final List<FreeRoom> free;
  final int basedOnGroups;

  factory FreeRooms.fromJson(Map<String, dynamic> j) => FreeRooms(
        [for (final r in j['free'] as List) FreeRoom.fromJson(r as Map<String, dynamic>)],
        j['basedOnGroups'] as int? ?? 0,
      );
}

class RoomDayLesson {
  const RoomDayLesson(this.group, this.item);
  final String group;
  final DayLesson item;
}

class RoomDay {
  const RoomDay({required this.known, required this.room, required this.basedOnGroups, required this.from, required this.to, required this.busy, required this.lessons});
  final bool known;
  final Room? room;
  final int basedOnGroups;
  final int from;
  final int to;
  final List<TimeSpan> busy;
  final List<RoomDayLesson> lessons;

  factory RoomDay.fromJson(Map<String, dynamic> j) => RoomDay(
        known: j['known'] as bool,
        room: j['room'] == null ? null : Room.fromJson(j['room'] as Map<String, dynamic>),
        basedOnGroups: j['basedOnGroups'] as int? ?? 0,
        from: (j['from'] as num).toInt(),
        to: (j['to'] as num).toInt(),
        busy: [for (final b in j['busy'] as List) TimeSpan((b['from'] as num).toInt(), (b['to'] as num).toInt())],
        lessons: [
          for (final l in j['lessons'] as List) RoomDayLesson(l['group'] as String, DayLesson.fromJson(l['item'] as Map<String, dynamic>)),
        ],
      );
}

int _byRoom(({String label, int building}) a, ({String label, int building}) b) {
  final c = a.building - b.building;
  return c != 0 ? c : compareRu(a.label, b.label, numeric: true);
}

List<SharedLesson> mergedLessons(List<GroupPackage> packages, bool Function(Lesson) predicate) {
  final rows = <String, SharedLesson>{};
  for (final pkg in packages) {
    for (final l in pkg.lessons.where(predicate)) {
      final rooms = [for (final r in l.rooms) r.label];
      final teachers = [for (final t in l.teachers) t.name];
      final key = jsonEncode([l.day, l.num, l.week, l.subgroup, l.subject, l.kind, rooms, teachers]);
      final existing = rows[key];
      if (existing != null) {
        if (!existing.groups.contains(pkg.code)) existing.groups.add(pkg.code);
      } else {
        rows[key] = SharedLesson(day: l.day, num: l.num, week: l.week, subgroup: l.subgroup, subject: l.subject, kind: l.kind, rooms: rooms, teachers: teachers, groups: [pkg.code]);
      }
    }
  }
  return stableSorted(rows.values, (a, b) => a.day != b.day ? a.day - b.day : a.num - b.num);
}

List<TeacherHit> teacherHits(List<GroupPackage> packages, String query) {
  final q = query.trim().toLowerCase();
  if (q.length == 1) return const [];
  final hits = <String, TeacherHit>{};
  for (final p in packages) {
    for (final l in p.lessons) {
      for (final t in l.teachers) {
        if (t.name.toLowerCase().contains(q)) hits[t.name] = TeacherHit(t.name, t.rank, (hits[t.name]?.lessons ?? 0) + 1);
      }
    }
  }
  final sorted = stableSorted(hits.values, (a, b) => compareRu(a.name, b.name));
  return q.isNotEmpty ? sorted.take(60).toList() : sorted;
}

List<SharedLesson> teacherSchedule(List<GroupPackage> packages, String name) => mergedLessons(packages, (l) => l.teachers.any((t) => t.name == name));

String _squash(String label) => label.replaceAll(RegExp(r'\s'), '');

List<SharedLesson> roomSchedule(List<GroupPackage> packages, String room) => mergedLessons(packages, (l) => l.rooms.any((r) => _squash(r.label) == _squash(room)));

Iterable<Lesson> _allLessons(GroupPackage pkg) sync* {
  yield* pkg.lessons;
  for (final o in pkg.overrides) {
    if (o.lesson != null) yield o.lesson!;
  }
}

FreeRooms roomList(List<GroupPackage> packages) {
  final rooms = <String, FreeRoom>{};
  for (final pkg in packages) {
    for (final lesson in _allLessons(pkg)) {
      for (final r in lesson.rooms) {
        if (!r.placeholder && r.building != null) rooms[r.label] = FreeRoom(label: r.label, building: r.building!, floor: r.floor);
      }
    }
  }
  final sorted = stableSorted(rooms.values, (a, b) => _byRoom((label: a.label, building: a.building), (label: b.label, building: b.building)));
  return FreeRooms(sorted, packages.length);
}

String shortKey(String label) => label.replaceAll(RegExp(r'\s'), '').toLowerCase();

RoomDay roomDay(List<GroupPackage> packages, String label, String date) {
  final day = parseYmd(date);
  if (day == null) throw ArgumentError('Некорректная дата');
  final names = shortKey(label);
  Room? known;
  for (final pkg in packages) {
    for (final l in _allLessons(pkg)) {
      for (final r in l.rooms) {
        if (known == null && !r.placeholder && shortKey(r.label) == names) known = r;
      }
    }
  }
  final lessons = <RoomDayLesson>[];
  for (final pkg in packages) {
    for (final item in lessonsForDate(pkg, day, 0, day)) {
      if (item.lesson.rooms.any((r) => !r.placeholder && shortKey(r.label) == names)) lessons.add(RoomDayLesson(pkg.code, item));
    }
  }
  final grids = [for (final pkg in packages) ...bellsForDay(pkg.bells ?? defaultBells, isoDay(day))];
  final basis = grids.isNotEmpty ? grids : bellsForDay(defaultBells, isoDay(day));
  final from = basis.map((b) => b.startMinutes).reduce((a, b) => a < b ? a : b);
  final to = basis.map((b) => b.endMinutes).reduce((a, b) => a > b ? a : b);
  final sortedLessons = stableSorted(lessons, (a, b) => a.item.bell.startMinutes - b.item.bell.startMinutes);
  final busy = <TimeSpan>[];
  for (final row in sortedLessons) {
    final f = row.item.bell.startMinutes, t = row.item.bell.endMinutes;
    if (busy.isNotEmpty && f <= busy.last.to) {
      busy.last.to = busy.last.to > t ? busy.last.to : t;
    } else {
      busy.add(TimeSpan(f, t));
    }
  }
  return RoomDay(known: known != null, room: known, basedOnGroups: packages.length, from: from, to: to, busy: busy, lessons: sortedLessons);
}

FreeRooms freeRoomsAt(List<GroupPackage> packages, String date, int minute, {int? building}) {
  final known = <String, Room>{};
  for (final pkg in packages) {
    for (final lesson in _allLessons(pkg)) {
      for (final room in lesson.rooms) {
        if (!room.placeholder && room.building != null && (building == null || building == 0 || room.building == building)) known[shortKey(room.label)] = room;
      }
    }
  }
  final day = parseYmd(date);
  if (day == null) throw ArgumentError('Некорректная дата');
  final dayLessons = [for (final pkg in packages) ...lessonsForDate(pkg, day, 0, day)];
  final occupied = <String>{};
  for (final item in dayLessons) {
    if (item.bell.startMinutes <= minute && item.bell.endMinutes > minute) {
      for (final r in item.lesson.rooms) {
        if (!r.placeholder) occupied.add(shortKey(r.label));
      }
    }
  }
  final nextBusy = <String, int>{};
  for (final item in dayLessons) {
    if (item.bell.startMinutes > minute) {
      for (final r in item.lesson.rooms) {
        if (!r.placeholder) {
          final name = shortKey(r.label);
          final prev = nextBusy[name];
          nextBusy[name] = prev == null || item.bell.startMinutes < prev ? item.bell.startMinutes : prev;
        }
      }
    }
  }
  final free = [
    for (final e in known.entries)
      if (!occupied.contains(e.key)) FreeRoom(label: e.value.label, building: e.value.building!, floor: e.value.floor, freeUntil: nextBusy[e.key]),
  ];
  return FreeRooms(stableSorted(free, (a, b) => _byRoom((label: a.label, building: a.building), (label: b.label, building: b.building))), packages.length);
}

String? shortTeacherName(String full) {
  final words = full.trim().split(RegExp(r'\s+'));
  if (words.length < 2 || words.length > 3 || words.skip(1).any((w) => w.length < 3 || w.contains('.'))) return null;
  return '${words[0]} ${words.skip(1).map((w) => '${w[0].toUpperCase()}.').join()}';
}

Map<String, String> teacherFullNames(List<String> list) {
  final names = <String, String>{};
  for (final full in list) {
    final short = shortTeacherName(full);
    if (short != null && !names.containsKey(short)) names[short] = full.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
  return names;
}

String fullTeacherName(String name, Map<String, String>? names) => names?[name] ?? name;
