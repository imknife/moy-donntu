import 'dart:math' as math;

class Road {
  const Road({required this.x, required this.y, required this.w, required this.h, this.name, this.atX, this.atY, this.rotate});
  final double x, y, w, h;
  final String? name;
  final double? atX, atY;
  final double? rotate;
}

class Decor {
  const Decor({required this.x, required this.y, required this.w, required this.h, this.label});
  final double x, y, w, h;
  final String? label;
}

class Block {
  const Block({required this.id, required this.points, required this.centerX, required this.centerY});
  final String id;
  final String points;
  final double centerX, centerY;

  List<(double, double)> get polygon => [
        for (final p in points.split(' ')) (double.parse(p.split(',')[0]), double.parse(p.split(',')[1])),
      ];
}

class CampusSite {
  const CampusSite({required this.title, required this.width, required this.height, required this.roads, required this.decor, required this.buildings});
  final String title;
  final double width, height;
  final List<Road> roads;
  final List<Decor> decor;
  final List<Block> buildings;
}

const maxScale = 4.0;

double clampValue(double value, double min, double max) => math.min(max, math.max(min, value));

double clampPan(double t, double scale, double size) => clampValue(t, -size * (scale - 1) / 2, size * (scale - 1) / 2);

({double scale, double tx, double ty, double width, double height}) viewOf(double scale, double tx, double ty, double width, double height) => (scale: scale, tx: tx, ty: ty, width: width, height: height);

(double, double) toViewBox(double x, double y, ({double scale, double tx, double ty, double width, double height}) v, CampusSite site) {
  final cx = (x - v.width / 2 - v.tx) / v.scale + v.width / 2;
  final cy = (y - v.height / 2 - v.ty) / v.scale + v.height / 2;
  return (cx * site.width / v.width, cy * site.height / v.height);
}

bool insidePolygon(double px, double py, List<(double, double)> pts) {
  var hit = false;
  for (var i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    final (xi, yi) = pts[i];
    final (xj, yj) = pts[j];
    if ((yi > py) != (yj > py) && px < (xj - xi) * (py - yi) / (yj - yi) + xi) hit = !hit;
  }
  return hit;
}

String? hitBuilding(CampusSite site, double x, double y, {double reach = 46}) {
  for (final b in site.buildings) {
    if (insidePolygon(x, y, b.polygon)) return b.id;
  }
  String? best;
  var bestDistance = double.infinity;
  for (final b in site.buildings) {
    final d = math.sqrt(math.pow(b.centerX - x, 2) + math.pow(b.centerY - y, 2));
    if (d <= reach && d < bestDistance) {
      best = b.id;
      bestDistance = d;
    }
  }
  return best;
}
