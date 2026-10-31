
class Bell {
  const Bell({required this.num, required this.start, required this.end, required this.startMinutes, required this.endMinutes});
  final int num;
  final String start;
  final String end;
  final int startMinutes;
  final int endMinutes;

  factory Bell.fromJson(Map<String, dynamic> j) => Bell(
        num: j['num'] as int,
        start: j['start'] as String,
        end: j['end'] as String,
        startMinutes: j['startMinutes'] as int,
        endMinutes: j['endMinutes'] as int,
      );
}

class BellGrids {
  const BellGrids({required this.weekday, required this.weekend});
  final List<Bell> weekday;
  final List<Bell> weekend;

  factory BellGrids.fromJson(Map<String, dynamic> j) => BellGrids(
        weekday: [for (final b in j['weekday'] as List) Bell.fromJson(b as Map<String, dynamic>)],
        weekend: [for (final b in j['weekend'] as List) Bell.fromJson(b as Map<String, dynamic>)],
      );
}

class Room {
  const Room({required this.label, required this.building, required this.floor, required this.placeholder, this.room});
  final String? room;
  final String label;
  final int? building;
  final int? floor;
  final bool placeholder;

  factory Room.fromJson(Map<String, dynamic> j) =>
      Room(label: j['label'] as String, building: j['building'] as int?, floor: j['floor'] as int?, placeholder: j['placeholder'] as bool? ?? false, room: j['room'] as String?);
}

class Teacher {
  const Teacher({required this.rank, required this.name});
  final String rank;
  final String name;

  factory Teacher.fromJson(Map<String, dynamic> j) => Teacher(rank: j['rank'] as String? ?? '', name: j['name'] as String);
}

class StreamGroup {
  const StreamGroup({required this.code, required this.subgroup});
  final String code;
  final int subgroup;
}

class Lesson {
  const Lesson({
    required this.day,
    required this.num,
    required this.week,
    required this.subgroup,
    required this.subject,
    required this.kind,
    required this.rooms,
    required this.teachers,
    this.stream = const [],
    this.teacherPending = false,
  });
  final int day;
  final int num;

  final String week;
  final int subgroup;
  final String subject;
  final String kind;
  final List<Room> rooms;
  final List<Teacher> teachers;
  final List<StreamGroup> stream;
  final bool teacherPending;

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        day: j['day'] as int,
        num: j['num'] as int,
        week: j['week'] as String,
        subgroup: j['subgroup'] as int,
        subject: j['subject'] as String,
        kind: j['kind'] as String,
        rooms: [for (final r in (j['rooms'] as List? ?? const [])) Room.fromJson(r as Map<String, dynamic>)],
        teachers: [for (final t in (j['teachers'] as List? ?? const [])) Teacher.fromJson(t as Map<String, dynamic>)],
        stream: [for (final g in (j['stream'] as List? ?? const [])) StreamGroup(code: g['code'] as String, subgroup: g['subgroup'] as int)],
        teacherPending: j['teacherPending'] as bool? ?? false,
      );

  Lesson withSubgroup(int s) => Lesson(day: day, num: num, week: week, subgroup: s, subject: subject, kind: kind, rooms: rooms, teachers: teachers, stream: stream, teacherPending: teacherPending);
}

class Override {
  const Override({required this.id, required this.date, required this.num, required this.subgroup, required this.action, required this.lesson, required this.note});
  final int id;
  final String date;
  final int num;
  final int subgroup;

  final String action;
  final Lesson? lesson;
  final String? note;

  factory Override.fromJson(Map<String, dynamic> j) => Override(
        id: j['id'] as int,
        date: j['date'] as String,
        num: j['num'] as int,
        subgroup: j['subgroup'] as int,
        action: j['action'] as String,
        lesson: j['lesson'] == null ? null : Lesson.fromJson(j['lesson'] as Map<String, dynamic>),
        note: j['note'] as String?,
      );
}

class FieldChange {
  const FieldChange({required this.field, required this.from, required this.to});
  final String field;
  final String from;
  final String to;

  factory FieldChange.fromJson(Map<String, dynamic> j) => FieldChange(field: j['field'] as String, from: j['from'] as String? ?? '', to: j['to'] as String? ?? '');
}

class LessonChange {
  const LessonChange({required this.type, required this.day, required this.num, required this.week, required this.subgroup, required this.subject, required this.fields});
  final String type;
  final int day;
  final int num;
  final String week;
  final int subgroup;
  final String subject;
  final List<FieldChange>? fields;

  factory LessonChange.fromJson(Map<String, dynamic> j) => LessonChange(
        type: j['type'] as String,
        day: j['day'] as int,
        num: j['num'] as int,
        week: j['week'] as String,
        subgroup: j['subgroup'] as int,
        subject: j['subject'] as String,
        fields: j['fields'] == null ? null : [for (final f in j['fields'] as List) FieldChange.fromJson(f as Map<String, dynamic>)],
      );
}

class LastChange {
  const LastChange({required this.publishedAt, required this.changes});
  final String publishedAt;
  final List<LessonChange> changes;

  factory LastChange.fromJson(Map<String, dynamic> j) => LastChange(
        publishedAt: j['publishedAt'] as String,
        changes: [for (final c in (j['diff'] as Map<String, dynamic>)['changes'] as List) LessonChange.fromJson(c as Map<String, dynamic>)],
      );
}

class Period {
  const Period({required this.kind, required this.from, required this.to});
  final String kind;
  final String from;
  final String to;
}

class Holiday {
  const Holiday({required this.date, required this.name});
  final String date;
  final String name;
}

class AcademicCalendar {
  const AcademicCalendar({required this.periods, required this.holidays});
  final List<Period> periods;
  final List<Holiday> holidays;

  factory AcademicCalendar.fromJson(Map<String, dynamic> j) => AcademicCalendar(
        periods: [for (final p in j['periods'] as List) Period(kind: p['kind'] as String, from: p['from'] as String, to: p['to'] as String)],
        holidays: [for (final h in j['holidays'] as List) Holiday(date: h['date'] as String, name: h['name'] as String)],
      );
}

class GroupPackage {
  const GroupPackage({
    required this.code,
    required this.semesterStart,
    required this.bells,
    required this.calendar,
    required this.lessons,
    required this.overrides,
    required this.lastChange,
    this.contentHash = '',
    this.updatedAt = '',
    this.version = 0,
  });
  final String contentHash;
  final String updatedAt;
  final int version;
  final String code;
  final String? semesterStart;
  final BellGrids? bells;
  final AcademicCalendar? calendar;
  final List<Lesson> lessons;
  final List<Override> overrides;
  final LastChange? lastChange;

  factory GroupPackage.fromJson(Map<String, dynamic> j) => GroupPackage(
        code: (j['group'] as Map<String, dynamic>)['code'] as String,
        semesterStart: (j['semester'] as Map<String, dynamic>)['start'] as String?,
        bells: j['bells'] == null ? null : BellGrids.fromJson(j['bells'] as Map<String, dynamic>),
        calendar: j['calendar'] == null ? null : AcademicCalendar.fromJson(j['calendar'] as Map<String, dynamic>),
        lessons: [for (final l in j['lessons'] as List) Lesson.fromJson(l as Map<String, dynamic>)],
        overrides: [for (final o in (j['overrides'] as List? ?? const [])) Override.fromJson(o as Map<String, dynamic>)],
        lastChange: j['lastChange'] == null ? null : LastChange.fromJson(j['lastChange'] as Map<String, dynamic>),
        contentHash: j['contentHash'] as String? ?? '',
        updatedAt: j['updatedAt'] as String? ?? '',
        version: j['version'] as int? ?? 0,
      );
}

class TimeSpan {
  TimeSpan(this.from, this.to);
  int from;
  int to;
}
