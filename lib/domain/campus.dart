import 'dart:math' as math;

import 'campus_data.dart';

class CampusBuilding {
  const CampusBuilding({required this.id, required this.title, required this.mark, required this.site, this.address, this.coords, required this.rooms});
  final String id;
  final String title;
  final String mark;
  final String site;
  final String? address;
  final (double, double)? coords;
  final bool rooms;
}

const campusBuildings = <CampusBuilding>[
  CampusBuilding(id: '1', title: 'Корпус 1 · главный', mark: '1', site: 'main', address: 'ул. Артёма, 58', coords: (47.994061, 37.804125), rooms: true),
  CampusBuilding(id: '2', title: 'Корпус 2', mark: '2', site: 'main', address: 'ул. Артёма, 58В', coords: (47.995144, 37.804222), rooms: true),
  CampusBuilding(id: '4', title: 'Корпус 4', mark: '4', site: 'main', address: 'ул. Кобозева, 17', coords: (47.994193, 37.802654), rooms: true),
  CampusBuilding(id: '5', title: 'Корпус 5', mark: '5', site: 'main', address: 'ул. Кобозева, 15', coords: (47.993517, 37.802487), rooms: true),
  CampusBuilding(id: '8', title: 'Корпус 8', mark: '8', site: 'main', address: 'просп. 25-летия РККА, 1', coords: (47.995154, 37.802285), rooms: true),
  CampusBuilding(id: '9', title: 'Корпус 9', mark: '9', site: 'main', address: 'ул. Артёма, 50', coords: (47.993, 37.803495), rooms: true),
  CampusBuilding(id: '11', title: 'Корпус 11', mark: '11', site: 'artema131', address: 'ул. Артёма, 131', coords: (48.012519, 37.803807), rooms: true),
  CampusBuilding(id: 'baz', title: 'БАЗ', mark: 'БАЗ', site: 'main', rooms: false),
];

CampusBuilding? campusBuilding(Object? id) {
  for (final b in campusBuildings) {
    if (b.id == '$id') return b;
  }
  return null;
}

const _walks = <String, (int, int)>{
  '1-2': (2, 149), '1-4': (5, 420), '1-5': (4, 360), '1-8': (5, 420), '1-9': (3, 230), '1-11': (26, 2170),
  '2-4': (5, 450), '2-5': (6, 470), '2-8': (3, 290), '2-9': (4, 340),
  '4-5': (1, 93), '4-8': (3, 206), '4-9': (3, 222),
  '5-8': (3, 241), '5-9': (2, 156), '8-9': (5, 400),
};

({int minutes, int meters})? campusWalk(Object a, Object b) {
  final pair = ['$a', '$b']..sort((p, q) => (num.tryParse(p) ?? double.nan).compareTo(num.tryParse(q) ?? double.nan));
  final walk = _walks['${pair[0]}-${pair[1]}'];
  return walk == null ? null : (minutes: walk.$1, meters: walk.$2);
}

({String building, String? room, int? floor})? parseRoomQuery(String raw) {
  final text = raw.trim().replaceFirst(RegExp(r'^корпус\s*', caseSensitive: false), '').replaceFirst(RegExp(r'\.\s+'), '.');
  final full = RegExp(r'^(\d{1,2})\.(\d{3})([а-яё]?)$', caseSensitive: false).firstMatch(text);
  if (full != null) {
    return (building: '${int.parse(full[1]!)}', room: full[2]! + full[3]!.toLowerCase(), floor: int.parse(full[2]![0]));
  }
  final only = RegExp(r'^(\d{1,2})$').firstMatch(text);
  return only == null ? null : (building: '${int.parse(only[1]!)}', room: null, floor: null);
}

String? yandexMapsUrl(CampusBuilding b) => b.address == null ? null : 'https://yandex.ru/maps/?text=${Uri.encodeComponent('Донецк, ${b.address}')}';

String? yandexRouteUrl(CampusBuilding from, CampusBuilding to) {
  if (from.coords == null || to.coords == null || from.id == to.id) return null;
  String point(CampusBuilding b) => '${b.coords!.$1},${b.coords!.$2}';
  return 'https://yandex.ru/maps/?rtext=${point(from)}~${point(to)}&rtt=pd';
}

typedef LngLat = (double, double);

LngLat _toLngLat((double, double) p) => (p.$2, p.$1);

final Map<String, LngLat> campusPathNodes = () {
  final nodes = <String, LngLat>{};
  for (final e in junctions.entries) {
    nodes[e.key] = _toLngLat(e.value);
  }
  for (final doors in entrances.values) {
    for (final e in doors.entries) {
      nodes[e.key] = _toLngLat(e.value);
    }
  }
  return nodes;
}();

List<String> campusEntrances(Object building) => (entrances['$building']?.keys ?? const <String>[]).toList();

String? _buildingOfNode(String node) {
  for (final e in entrances.entries) {
    if (e.value.containsKey(node)) return e.key;
  }
  return null;
}

double geoDistance(LngLat a, LngLat b) {
  const rad = math.pi / 180;
  final dLat = (b.$2 - a.$2) * rad;
  final dLng = (b.$1 - a.$1) * rad;
  final h = math.pow(math.sin(dLat / 2), 2) + math.cos(a.$2 * rad) * math.cos(b.$2 * rad) * math.pow(math.sin(dLng / 2), 2);
  return 2 * 6371008.8 * math.asin(math.min(1, math.sqrt(h)));
}

double lineLength(List<LngLat> line) {
  var sum = 0.0;
  for (var i = 1; i < line.length; i++) {
    sum += geoDistance(line[i - 1], line[i]);
  }
  return sum;
}

class _Link {
  const _Link(this.to, this.meters, this.line, this.through);
  final String to;
  final double meters;
  final List<LngLat> line;
  final bool through;
}

List<LngLat> _edgeLine(({String a, String b, List<(double, double)> via, bool through}) e) => [campusPathNodes[e.a]!, ...e.via.map(_toLngLat), campusPathNodes[e.b]!];

final Map<String, List<_Link>> _graph = () {
  final graph = <String, List<_Link>>{};
  void add(String from, _Link link) => (graph[from] ??= []).add(link);
  for (final e in edges) {
    if (!campusPathNodes.containsKey(e.a) || !campusPathNodes.containsKey(e.b)) continue;
    final line = _edgeLine(e);
    final meters = lineLength(line);
    add(e.a, _Link(e.b, meters, line, e.through));
    add(e.b, _Link(e.a, meters, line.reversed.toList(), e.through));
  }
  return graph;
}();

class CampusPathRoute {
  const CampusPathRoute(this.nodes, this.coordinates, this.meters);
  final List<String> nodes;
  final List<LngLat> coordinates;
  final int meters;
}

CampusPathRoute? campusPathRoute(Object from, Object to) {
  final starts = campusEntrances(from);
  final goals = campusEntrances(to).toSet();
  if ('$from' == '$to' || starts.isEmpty || goals.isEmpty) return null;
  return _shortest(starts, goals, false) ?? _shortest(starts, goals, true);
}

CampusPathRoute? _shortest(List<String> starts, Set<String> goals, bool through) {
  final dist = <String, double>{for (final s in starts) s: 0};
  final prev = <String, ({String node, _Link link})>{};
  final done = <String>{};
  String goal;
  while (true) {
    String? current;
    for (final e in dist.entries) {
      if (!done.contains(e.key) && (current == null || e.value < dist[current]!)) current = e.key;
    }
    if (current == null) return null;
    if (goals.contains(current)) {
      goal = current;
      break;
    }
    done.add(current);
    for (final link in _graph[current] ?? const <_Link>[]) {
      if (link.through && !through) continue;
      final next = dist[current]! + link.meters;
      if (next < (dist[link.to] ?? double.infinity)) {
        dist[link.to] = next;
        prev[link.to] = (node: current, link: link);
      }
    }
  }
  final parts = <_Link>[];
  final nodes = [goal];
  var node = goal;
  while (prev.containsKey(node)) {
    final step = prev[node]!;
    parts.insert(0, step.link);
    nodes.insert(0, step.node);
    node = step.node;
  }
  final coordinates = <LngLat>[];
  for (final part in parts) {
    coordinates.addAll(coordinates.isNotEmpty ? part.line.skip(1) : part.line);
  }
  return CampusPathRoute(nodes, coordinates, dist[goal]!.round());
}

const walkMetersPerMinute = 80;

({int minutes, int meters})? campusPathWalk(Object from, Object to) {
  final route = campusPathRoute(from, to);
  if (route == null) return null;
  return (minutes: math.max(1, (route.meters / walkMetersPerMinute).ceil()), meters: route.meters);
}

List<String> reachableBuildings(Object from) {
  final seen = <String>{...campusEntrances(from)};
  final queue = [...seen];
  while (queue.isNotEmpty) {
    for (final link in _graph[queue.removeAt(0)] ?? const <_Link>[]) {
      if (seen.add(link.to)) queue.add(link.to);
    }
  }
  final out = <String>[];
  for (final n in seen) {
    final b = _buildingOfNode(n);
    if (b != null && !out.contains(b)) out.add(b);
  }
  return out;
}
