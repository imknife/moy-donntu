import '../domain/brand.dart';
import '../domain/directory.dart';
import '../domain/models.dart';
import 'loader.dart';
import 'resources.dart';

class ChangeVersion {
  const ChangeVersion(this.version, this.publishedAt, this.changes);
  final int version;
  final String publishedAt;
  final List<LessonChange> changes;
}

List<GroupInfo> parseGroupList(Object? j) {
  final list = (j as Map<String, dynamic>)['groups'] as List;
  return [
    for (final g in list)
      if ((g as Map<String, dynamic>)['hasSchedule'] == true) GroupInfo(g['code'] as String, g['course'] as int?, g['faculty'] as String? ?? ''),
  ];
}

GroupPackage parsePackage(Object? j) => GroupPackage.fromJson(j as Map<String, dynamic>);

List<ChangeVersion> parseChanges(Object? j) => [
      for (final c in (j as Map<String, dynamic>)['changes'] as List)
        ChangeVersion(
          c['version'] as int,
          c['publishedAt'] as String,
          [for (final x in ((c['diff'] as Map<String, dynamic>)['changes'] as List)) LessonChange.fromJson(x as Map<String, dynamic>)],
        ),
    ];

Features parseFeatures(Object? j) => Features.fromJson(j as Map<String, dynamic>);

String parseBrand(Object? j) => (j as Map<String, dynamic>)['id'] as String? ?? 'pairs';

Map<String, String> parseNames(Object? j) {
  final names = (j as Map<String, dynamic>)['names'];
  if (names is Map) return names.cast<String, String>();
  if (names is List) return teacherFullNames(names.cast<String>());
  return const {};
}

List<TeacherHit> parseTeachers(Object? j) => [for (final t in (j as Map<String, dynamic>)['teachers'] as List) TeacherHit.fromJson(t as Map<String, dynamic>)];

List<SharedLesson> parseShared(Object? j) => [for (final l in (j as Map<String, dynamic>)['lessons'] as List) SharedLesson.fromJson(l as Map<String, dynamic>)];

FreeRooms parseFreeRooms(Object? j) => FreeRooms.fromJson(j as Map<String, dynamic>);

RoomDay parseRoomDay(Object? j) => RoomDay.fromJson(j as Map<String, dynamic>);

ResourceSpec<List<GroupInfo>> groupsSpec() => const ResourceSpec('/groups', parseGroupList);

bool keepFilledPackage(GroupPackage previous, GroupPackage fresh) => fresh.lessons.isEmpty && previous.lessons.isNotEmpty;

ResourceSpec<GroupPackage> packageSpec(String code) => ResourceSpec('/groups/${Uri.encodeComponent(code)}/package', parsePackage, keepPrevious: keepFilledPackage);

ResourceSpec<List<ChangeVersion>> changesSpec(String code) => ResourceSpec('/groups/${Uri.encodeComponent(code)}/changes', parseChanges);

ResourceSpec<Features> featuresSpec() => const ResourceSpec('/features', parseFeatures);

ResourceSpec<String> brandSpec() => const ResourceSpec('/brand', parseBrand);

ResourceSpec<Map<String, String>> teacherNamesSpec() => const ResourceSpec('/teacher-names', parseNames);

ResourceSpec<List<TeacherHit>> teachersSpec() => const ResourceSpec('/teachers?q=', parseTeachers);

ResourceSpec<List<SharedLesson>> teacherScheduleSpec(String name) => ResourceSpec('/teachers/${Uri.encodeComponent(name)}/schedule', parseShared);

ResourceSpec<FreeRooms> roomsSpec() => const ResourceSpec('/rooms', parseFreeRooms);

ResourceSpec<FreeRooms> freeRoomsSpec(String date, int minute, {int? building}) =>
    ResourceSpec('/rooms/available?date=$date&minute=$minute${building != null ? '&building=$building' : ''}', parseFreeRooms);

ResourceSpec<RoomDay> roomDaySpec(String room, String date) => ResourceSpec('/rooms/${Uri.encodeComponent(room)}/day?date=$date', parseRoomDay);
