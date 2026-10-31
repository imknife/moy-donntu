import 'campus.dart';
import 'schedule.dart';

class RouteEnds {
  const RouteEnds({this.from, this.to});
  final String? from;
  final String? to;

  RouteEnds copyWith({String? from, String? to, bool clearFrom = false, bool clearTo = false}) =>
      RouteEnds(from: clearFrom ? null : (from ?? this.from), to: clearTo ? null : (to ?? this.to));

  @override
  bool operator ==(Object other) => other is RouteEnds && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

({DayLesson item, String building})? nextLessonWithBuilding(List<DayLesson> items, int minute) {
  for (final item in items) {
    if (item.bell.endMinutes <= minute) continue;
    final b = buildingOf(item.lesson);
    if (b != null) return (item: item, building: '$b');
  }
  return null;
}

RouteEnds routeFromLessons(List<DayLesson> items, int minute) {
  final index = items.indexWhere((item) => item.bell.endMinutes > minute && buildingOf(item.lesson) != null);
  if (index < 0) return const RouteEnds();
  final to = '${buildingOf(items[index].lesson)}';
  for (var i = index - 1; i >= 0; i--) {
    final before = buildingOf(items[i].lesson);
    if (before != null) return RouteEnds(from: '$before', to: to);
  }
  return RouteEnds(to: to);
}

RouteEnds resolveRoute(RouteEnds params, RouteEnds auto) {
  if (params.from == null && params.to == null) return auto;
  final to = campusBuilding(params.to)?.id;
  return RouteEnds(from: campusBuilding(params.from)?.id ?? (to != null && to == auto.to ? auto.from : null), to: to);
}

RouteEnds swapRoute(RouteEnds r) => RouteEnds(from: r.to, to: r.from);

sealed class RouteSummary {
  const RouteSummary();
}

class RouteWalk extends RouteSummary {
  const RouteWalk(this.minutes, this.meters);
  final int minutes;
  final int meters;
}

class RouteSame extends RouteSummary {
  const RouteSame();
}

class RouteUnknown extends RouteSummary {
  const RouteUnknown();
}

RouteSummary? routeSummary(RouteEnds r) {
  if (r.from == null || r.to == null || r.from!.isEmpty || r.to!.isEmpty) return null;
  if (r.from == r.to) return const RouteSame();
  final walk = campusPathWalk(r.from!, r.to!) ?? campusWalk(r.from!, r.to!);
  return walk == null ? const RouteUnknown() : RouteWalk(walk.minutes, walk.meters);
}

String? routeLink(RouteEnds r) {
  final a = campusBuilding(r.from);
  final b = campusBuilding(r.to);
  return a != null && b != null ? yandexRouteUrl(a, b) : null;
}

String routeCaption(RouteEnds r) {
  String name(String? id) {
    final b = campusBuilding(id);
    return b != null ? b.title.split(' ·')[0] : 'выберите корпус';
  }

  return '${name(r.from)} → ${name(r.to)}';
}

class BuildingHit {
  const BuildingHit(this.building, this.kind, {this.room});
  final CampusBuilding building;
  final String? room;
  final String kind;
}

String _fold(String text) => text.toLowerCase().replaceAll('ё', 'е').replaceAll(RegExp(r'\s+'), ' ').trim();

List<BuildingHit> searchBuildings(String query, {int limit = 6}) {
  final text = _fold(query);
  if (text.isEmpty) return const [];
  final hits = <BuildingHit>[];
  final seen = <String>{};
  void add(BuildingHit hit) {
    if (!seen.contains(hit.building.id) && hits.length < limit) {
      seen.add(hit.building.id);
      hits.add(hit);
    }
  }

  final parsed = parseRoomQuery(query);
  final exact = parsed == null ? null : campusBuilding(parsed.building);
  if (exact != null) add(BuildingHit(exact, parsed!.room != null ? 'room' : 'building', room: parsed.room != null ? '${parsed.building}.${parsed.room}' : null));
  if (RegExp(r'^\d+$').hasMatch(text) || parsed?.room != null) return hits;
  for (final b in campusBuildings) {
    if (_fold(b.mark) == text) add(BuildingHit(b, 'building'));
  }
  for (final b in campusBuildings) {
    if (_fold('${b.title} ${b.address ?? ''}').contains(text)) add(BuildingHit(b, 'text'));
  }
  return hits;
}
