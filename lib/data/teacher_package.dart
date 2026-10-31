import '../domain/directory.dart';
import '../domain/models.dart';

GroupPackage teacherPackage(String name, List<SharedLesson> lessons, GroupPackage? base) => GroupPackage(
      code: name,
      semesterStart: base?.semesterStart,
      bells: base?.bells,
      calendar: base?.calendar,
      lessons: [
        for (final l in lessons)
          Lesson(
            day: l.day,
            num: l.num,
            week: l.week,
            subgroup: l.subgroup,
            subject: l.subject,
            kind: l.kind,
            rooms: [for (final r in l.rooms) Room(label: r, building: null, floor: null, placeholder: false)],
            teachers: [for (final t in (l.teachers.isEmpty ? [name] : l.teachers)) Teacher(rank: '', name: t)],
            stream: [for (final g in l.groups) StreamGroup(code: g, subgroup: 0)],
          ),
      ],
      overrides: const [],
      lastChange: null,
      contentHash: '$name:${lessons.length}',
      version: 1,
    );
