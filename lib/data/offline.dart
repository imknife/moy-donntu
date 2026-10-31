import 'dart:convert';
import 'dart:isolate';

import '../domain/directory.dart';
import '../domain/models.dart';

Future<Object?> offlineAnswer(String path, List<String> packageTexts) {
  if (packageTexts.isEmpty) return Future.value(null);
  final url = Uri.parse(path);
  final parts = url.pathSegments;
  final known = (parts.isNotEmpty && parts[0] == 'teachers') || (parts.isNotEmpty && parts[0] == 'rooms');
  if (!known) return Future.value(null);
  return Isolate.run(() => answerFrom(path, [for (final t in packageTexts) GroupPackage.fromJson(jsonDecode(t) as Map<String, dynamic>)]));
}

Object? answerFrom(String path, List<GroupPackage> packages) {
  final url = Uri.parse(path);
  final parts = url.pathSegments;
  final q = url.queryParameters;
  if (parts.isEmpty || packages.isEmpty) return null;
  if (parts[0] == 'teachers') {
    if (parts.length == 1) return teacherHits(packages, q['q'] ?? '');
    if (parts.length >= 3 && parts[2] == 'schedule') return teacherSchedule(packages, parts[1]);
  }
  if (parts[0] == 'rooms') {
    if (parts.length == 1) return roomList(packages);
    if (parts[1] == 'available') {
      final building = q['building'] == null ? null : int.tryParse(q['building']!);
      return freeRoomsAt(packages, q['date'] ?? '', int.tryParse(q['minute'] ?? '') ?? 0, building: building);
    }
    if (parts.length >= 3 && parts[2] == 'day') return roomDay(packages, parts[1], q['date'] ?? '');
    if (parts.length >= 3 && parts[2] == 'schedule') return roomSchedule(packages, parts[1]);
  }
  return null;
}
