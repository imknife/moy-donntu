import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/campus.dart';
import '../domain/campus_route.dart';
import '../domain/campus_schema.dart';
import '../domain/campus_sites.dart';
import '../domain/schedule.dart';
import 'common.dart';
import 'derived.dart';
import 'icons.dart';
import 'not_found.dart';
import 'scope.dart';
import 'theme.dart';
import 'widgets.dart';
import 'type_settings.dart';

String? shortTitle(String? id) {
  final b = campusBuilding(id);
  return b?.title.split(' ·')[0];
}

class CampusSchemeMap extends StatefulWidget {
  const CampusSchemeMap({super.key, required this.siteId, this.selected, this.next, this.route = const RouteEnds(), required this.onSelect});
  final String siteId;
  final String? selected;
  final String? next;
  final RouteEnds route;
  final void Function(String id) onSelect;

  @override
  State<CampusSchemeMap> createState() => _CampusSchemeMapState();
}

class _CampusSchemeMapState extends State<CampusSchemeMap> {
  final TransformationController _transform = TransformationController();

  CampusSite get _site => campusSites[widget.siteId]!;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _zoom(double factor, Size size) {
    final current = _transform.value.getMaxScaleOnAxis();
    final next = clampValue(current * factor, 1, maxScale);
    final k = next / current;
    final center = Offset(size.width / 2, size.height / 2);
    final m = _transform.value.clone();
    final scaleMatrix = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(k, k, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);
    final result = scaleMatrix * m;
    _transform.value = _clampPan(result, size);
  }

  Matrix4 _clampPan(Matrix4 m, Size size) {
    final scale = m.getMaxScaleOnAxis();
    if (scale <= 1.001) return Matrix4.identity();
    final t = m.getTranslation();
    final minX = size.width - size.width * scale;
    final minY = size.height - size.height * scale;
    final tx = t.x.clamp(minX, 0.0);
    final ty = t.y.clamp(minY, 0.0);
    return Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final site = _site;
    return LayoutBuilder(builder: (context, box) {
      final width = box.maxWidth;
      final height = width * site.height / site.width;
      final size = Size(width, height);
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
          child: Stack(children: [
            Semantics(
              label: 'Схема кампуса, не GPS-карта. Корпуса перечислены списком ниже.',
              child: InteractiveViewer(
                transformationController: _transform,
                minScale: 1,
                maxScale: maxScale,
                boundaryMargin: EdgeInsets.zero,
                child: GestureDetector(
                  onTapUp: (d) {
                    final x = d.localPosition.dx * site.width / width;
                    final y = d.localPosition.dy * site.height / height;
                    final id = hitBuilding(site, x, y);
                    if (id != null) widget.onSelect(id);
                  },
                  child: CustomPaint(size: size, painter: _SchemePainter(site, c, widget.selected, widget.next, widget.route)),
                ),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Row(children: [
                _MapButton(icon: 'plus', label: 'Приблизить схему', onTap: () => _zoom(1.6, size)),
                const SizedBox(width: 6),
                _MapButton(icon: 'minus', label: 'Отдалить схему', onTap: () => _zoom(1 / 1.6, size)),
                const SizedBox(width: 6),
                _MapButton(icon: 'fit', label: 'Вся схема', onTap: () => _transform.value = Matrix4.identity()),
              ]),
            ),
          ]),
        ),
      );
    });
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.label, required this.onTap});
  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Tap(
      label: label,
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.center,
        child: AppIcon(icon, size: 18, color: c.text),
      ),
    );
  }
}

class _SchemePainter extends CustomPainter {
  _SchemePainter(this.site, this.pal, this.selected, this.next, this.route);
  final CampusSite site;
  final Pal pal;
  final String? selected;
  final String? next;
  final RouteEnds route;

  void _text(Canvas canvas, String text, Offset at, double fontSize, Color color, {double rotate = 0, FontWeight weight = FontWeight.w500}) {
    final tp = TextPainter(text: TextSpan(text: text, style: TextStyle(fontFamily: 'Onest', fontSize: fontSize, color: color, fontWeight: weight)), textDirection: TextDirection.ltr)..layout();
    canvas.save();
    canvas.translate(at.dx, at.dy);
    if (rotate != 0) canvas.rotate(rotate * math.pi / 180);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / site.width, size.height / site.height);
    final fill = Paint();
    for (final r in site.roads) {
      canvas.drawRect(Rect.fromLTWH(r.x, r.y, r.w, r.h), fill..color = pal.background);
      if (r.name != null && r.atX != null) _text(canvas, r.name!, Offset(r.atX!, r.atY!), 22, pal.muted, rotate: r.rotate ?? 0);
    }
    for (final d in site.decor) {
      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(d.x, d.y, d.w, d.h), const Radius.circular(8));
      canvas.drawRRect(rect, Paint()..color = pal.surface);
      canvas.drawRRect(rect, Paint()..color = pal.border..style = PaintingStyle.stroke..strokeWidth = 2);
      if (d.label != null) _text(canvas, d.label!, Offset(d.x + d.w / 2, d.y + d.h / 2), 24, pal.muted);
    }
    for (final b in site.buildings) {
      final on = b.id == selected;
      final highlighted = on || b.id == next;
      final path = Path();
      final pts = b.polygon;
      path.moveTo(pts.first.$1, pts.first.$2);
      for (final p in pts.skip(1)) {
        path.lineTo(p.$1, p.$2);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = highlighted ? pal.tint : pal.surface);
      canvas.drawPath(path, Paint()..color = on ? pal.link : pal.muted..style = PaintingStyle.stroke..strokeWidth = on ? 6 : 2.5..strokeJoin = StrokeJoin.round);
    }
    Block? find(String? id) {
      for (final b in site.buildings) {
        if (b.id == id) return b;
      }
      return null;
    }

    final a = find(route.from);
    final z = find(route.to);
    if (a != null && z != null) {
      final line = Path()..moveTo(a.centerX, a.centerY)..lineTo(z.centerX, z.centerY);
      for (final metric in line.computeMetrics()) {
        var d = 0.0;
        while (d < metric.length) {
          canvas.drawPath(metric.extractPath(d, math.min(d + 6, metric.length)), Paint()..color = pal.link..style = PaintingStyle.stroke..strokeWidth = 7..strokeCap = StrokeCap.round);
          d += 22;
        }
      }
    }
    for (final b in site.buildings) {
      final filled = b.id == selected || b.id == next;
      final mark = campusBuilding(b.id)?.mark ?? b.id;
      final long = mark.length > 2;
      final r = long ? 34.0 : 28.0;
      final center = Offset(b.centerX, b.centerY);
      canvas.drawCircle(center, r, Paint()..color = filled ? pal.link : pal.surface);
      canvas.drawCircle(center, r, Paint()..color = filled ? pal.link : pal.muted..style = PaintingStyle.stroke..strokeWidth = 2.5);
      _text(canvas, mark, center, long ? 22 : 30, filled ? pal.onLink : pal.text, weight: FontWeight.w600);
      if (b.id == route.from || b.id == route.to) {
        final badge = Offset(b.centerX + r * 0.75, b.centerY - r * 0.75);
        canvas.drawCircle(badge, 16, Paint()..color = pal.link);
        _text(canvas, b.id == route.from ? 'А' : 'Б', badge, 20, pal.onLink, weight: FontWeight.w600);
      }
    }
  }

  @override
  bool shouldRepaint(_SchemePainter old) => old.selected != selected || old.next != next || old.route != route || old.pal != pal || old.site != site;
}

class CampusPage extends StatefulWidget {
  const CampusPage({super.key, this.building, this.from, this.to});
  final String? building;
  final String? from;
  final String? to;

  @override
  State<CampusPage> createState() => _CampusPageState();
}

class _CampusPageState extends State<CampusPage> {
  late String? _selected = campusBuilding(widget.building)?.id;
  String? _room;
  late String _site = (campusBuilding(widget.to) ?? campusBuilding(widget.building))?.site ?? 'main';
  RouteEnds? _picked;
  String? _picking;
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  ({RouteEnds auto, ({DayLesson item, String building})? next}) _schedule() {
    final app = context.app;
    final model = app.model.value;
    if (model == null) return (auto: const RouteEnds(), next: null);
    final today = app.clock.value.today;
    final minute = app.clock.value.minute;
    final todayItems = model.items(today);
    final tomorrow = nextStudyDay(model.pkg, today, model.subgroup, model.nowInstant)?.items ?? const <DayLesson>[];
    final first = routeFromLessons(todayItems, minute);
    final ends = first.to != null ? first : routeFromLessons(tomorrow, 0);
    return (auto: ends, next: nextLessonWithBuilding(todayItems, minute) ?? nextLessonWithBuilding(tomorrow, 0));
  }

  void _choose(String id, {String? room}) {
    final b = campusBuilding(id);
    if (b == null) return;
    setState(() {
      _selected = id;
      _room = room;
      _site = b.site;
    });
  }

  void _setEnds(RouteEnds ends) {
    setState(() {
      _picked = ends;
      final focus = campusBuilding(ends.to ?? ends.from);
      if (focus != null) _site = focus.site;
    });
  }

  void _assign(String id, RouteEnds route) {
    if (_picking == null) return;
    _setEnds(_picking == 'from' ? route.copyWith(from: id) : route.copyWith(to: id));
    setState(() {
      _selected = id;
      _room = null;
      _picking = null;
      _query.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final sched = _schedule();
    final route = _picked ?? resolveRoute(RouteEnds(from: widget.from, to: widget.to), sched.auto);
    final summary = routeSummary(route);
    final link = routeLink(route);
    final current = campusBuilding(_selected);
    final onMap = _picking != null ? (String id) => _assign(id, route) : _choose;
    final showPanel = route.from != null || route.to != null || _picking != null;
    final sameSite = route.from == null || route.to == null || campusBuilding(route.from)?.site == campusBuilding(route.to)?.site;
    final hint = !sameSite
        ? 'Корпуса на разных схемах: путь между ними покажут Яндекс Карты.'
        : (route.from != null && route.to != null && route.from != route.to ? 'Путь пешком покажут Яндекс Карты.' : 'Схема не GPS: контуры обведены по иллюстрации кампуса.');
    final summaryText = _picking != null
        ? 'Нажмите корпус на схеме или найдите его в поиске.'
        : switch (summary) {
            RouteWalk() => '≈ ${summary.minutes} мин пешком · ${summary.meters} м',
            RouteSame() => 'Это один и тот же корпус: идти никуда не нужно.',
            RouteUnknown() => 'Время в пути для этой пары пока не посчитано.',
            null => 'Выберите второй корпус: покажем время в пути.',
          };
    final onRouteEnd = current != null && (current.id == route.from || current.id == route.to);
    final yandexUrl = onRouteEnd && link != null ? link : (current == null ? null : yandexMapsUrl(current));
    final yandexLabel = onRouteEnd && link != null ? 'Маршрут в Яндекс Картах' : 'Открыть в Яндекс Картах';
    final routeUrl = _picking == null && route.from != route.to ? link : null;
    final hits = searchBuildings(_query.text);
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 12, 0),
              child: Row(children: [
                Tap(label: 'Назад', onTap: () => Navigator.of(context).maybePop(), child: SizedBox(width: 48, height: 56, child: Center(child: AppIcon('back', size: 22, color: c.text)))),
                Expanded(child: _SearchField(controller: _query, onChanged: () => setState(() {}))),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                children: [
                  if (_query.text.trim().isNotEmpty)
                    SurfaceCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: hits.isEmpty
                          ? const Padding(padding: EdgeInsets.all(4), child: NothingFound(hint: 'Такого корпуса нет. Введите номер корпуса или аудиторию в формате 4.418.'))
                          : Column(children: [
                              for (final hit in hits)
                                MenuRow(
                                  icon: 'campus',
                                  title: hit.building.title,
                                  detail: hit.building.address ?? 'Адрес уточняется',
                                  trailing: hit.room != null ? Text('ауд. ${hit.room}'.cased, style: T.caption.copyWith(color: c.muted)) : const SizedBox(width: 0),
                                  onTap: () {
                                    if (_picking != null) {
                                      _assign(hit.building.id, route);
                                    } else {
                                      _query.clear();
                                      _choose(hit.building.id, room: hit.room);
                                    }
                                  },
                                ),
                            ]),
                    )
                  else if (showPanel) ...[
                    _RoutePanel(
                      route: route,
                      picking: _picking,
                      summaryText: summaryText,
                      routeUrl: routeUrl,
                      onPick: (which) => setState(() => _picking = _picking == which ? null : which),
                      onSwap: () {
                        _setEnds(swapRoute(route));
                        setState(() => _picking = null);
                      },
                      onClear: () => setState(() {
                        _picked = const RouteEnds();
                        _picking = null;
                      }),
                    ),
                  ],
                  const VGap(8),
                  ChipRow(options: [for (final e in campusSites.values) e.title], value: campusSites[_site]!.title, onChanged: (title) => setState(() => _site = campusSites.entries.firstWhere((e) => e.value.title == title).key)),
                  const VGap(8),
                  CampusSchemeMap(key: ValueKey(_site), siteId: _site, selected: _selected, next: sched.next?.building, route: route, onSelect: onMap),
                  const VGap(4),
                  Text(hint, style: T.caption.copyWith(color: c.muted)),
                  const SectionLabel('Корпуса'),
                  SurfaceCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(children: [
                      for (final b in campusBuildings)
                        MenuRow(
                          icon: 'campus',
                          title: b.title,
                          detail: b.address ?? 'Адрес уточняется',
                          trailing: sched.next?.building == b.id ? Text('пара'.cased, style: T.caption.copyWith(color: c.link)) : null,
                          onTap: () => onMap(b.id),
                        ),
                    ]),
                  ),
                ],
              ),
            ),
            if (current != null)
              _Dock(
                current: current,
                room: _room,
                isNext: sched.next?.building == current.id,
                yandexUrl: yandexUrl,
                yandexLabel: yandexLabel,
                onRouteTo: () {
                  _setEnds(route.copyWith(to: current.id));
                  setState(() => _picking = null);
                },
                onRouteFrom: () {
                  _setEnds(route.copyWith(from: current.id));
                  setState(() => _picking = null);
                },
                onClose: () => setState(() => _selected = null),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      style: T.body.copyWith(color: c.text),
      cursorColor: c.link,
      decoration: InputDecoration(
        hintText: 'Корпус или аудитория, например 4.418',
        hintStyle: T.body.copyWith(color: c.muted),
        prefixIcon: Padding(padding: const EdgeInsets.all(12), child: AppIcon('search', size: 20, color: c.muted)),
        filled: true,
        fillColor: c.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }
}

class _EndPill extends StatelessWidget {
  const _EndPill({required this.mark, required this.label, required this.value, required this.active, required this.onTap});
  final String mark;
  final String label;
  final String? value;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Expanded(
      child: Tap(
        label: '$label: ${value ?? 'не выбрано'}',
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(14), border: Border.all(color: active ? c.link : Colors.transparent, width: 1.5)),
          child: Row(children: [
            Container(width: 24, height: 24, decoration: BoxDecoration(color: c.link, shape: BoxShape.circle), alignment: Alignment.center, child: Text(mark, style: T.captionSemi.copyWith(color: c.onLink, fontSize: 12))),
            const SizedBox(width: 8),
            Expanded(child: Text(value ?? 'Корпус', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.subject.copyWith(color: value != null ? c.text : c.muted, fontWeight: FontWeight.w600))),
          ]),
        ),
      ),
    );
  }
}

class _RoutePanel extends StatelessWidget {
  const _RoutePanel({required this.route, required this.picking, required this.summaryText, required this.routeUrl, required this.onPick, required this.onSwap, required this.onClear});
  final RouteEnds route;
  final String? picking;
  final String summaryText;
  final String? routeUrl;
  final void Function(String which) onPick;
  final VoidCallback onSwap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return SurfaceCard(
      padding: const EdgeInsets.all(10),
      child: Column(children: [
        Row(children: [
          _EndPill(mark: 'А', label: 'Откуда', value: shortTitle(route.from), active: picking == 'from', onTap: () => onPick('from')),
          Tap(label: 'Поменять местами', onTap: onSwap, child: SizedBox(width: 44, height: 44, child: Center(child: AppIcon('swap', size: 20, color: c.text)))),
          _EndPill(mark: 'Б', label: 'Куда', value: shortTitle(route.to), active: picking == 'to', onTap: () => onPick('to')),
        ]),
        const VGap(8),
        Row(children: [
          Expanded(child: Text(summaryText, style: T.subject.copyWith(color: c.text))),
          Tap(label: 'Убрать маршрут', onTap: onClear, child: SizedBox(width: 44, height: 44, child: Center(child: AppIcon('close', size: 20, color: c.text)))),
        ]),
        if (routeUrl != null) PrimaryButton(label: 'Маршрут в Яндекс Картах', onTap: () => launchUrl(Uri.parse(routeUrl!), mode: LaunchMode.externalApplication)),
      ]),
    );
  }
}

class _Dock extends StatelessWidget {
  const _Dock({required this.current, required this.room, required this.isNext, required this.yandexUrl, required this.yandexLabel, required this.onRouteTo, required this.onRouteFrom, required this.onClose});
  final CampusBuilding current;
  final String? room;
  final bool isNext;
  final String? yandexUrl;
  final String yandexLabel;
  final VoidCallback onRouteTo;
  final VoidCallback onRouteFrom;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.5),
      decoration: BoxDecoration(color: c.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(current.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.heading.copyWith(color: c.text))),
            Tap(label: 'Закрыть карточку', onTap: onClose, child: SizedBox(width: 40, height: 40, child: Center(child: AppIcon('close', size: 20, color: c.text)))),
          ]),
          Text(current.address != null ? '${current.address}, Донецк' : 'Адрес уточняется', style: T.body.copyWith(color: c.muted)),
          if (isNext)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: c.tint, borderRadius: BorderRadius.circular(10)), child: Text('Следующая пара здесь'.cased, style: T.captionMedium.copyWith(color: c.text))),
            ),
          const VGap(10),
          Row(children: [
            Expanded(child: PrimaryButton(label: 'Маршрут сюда', onTap: onRouteTo)),
            const SizedBox(width: 8),
            Expanded(child: PrimaryButton(label: 'Маршрут отсюда', secondary: true, onTap: onRouteFrom)),
          ]),
          if (room != null) MenuRow(icon: 'room', title: 'Аудитория $room', detail: 'Занятость по расписанию', onTap: () => context.open('room', {'room': room!})),
          if (current.rooms) ...[const VGap(8), PrimaryButton(label: 'Аудитории корпуса', secondary: true, onTap: () => context.open('rooms', {'building': current.id}))],
          if (yandexUrl != null) ...[const VGap(8), PrimaryButton(label: yandexLabel, secondary: true, onTap: () => launchUrl(Uri.parse(yandexUrl!), mode: LaunchMode.externalApplication))],
          const VGap(8),
          Text('Адреса и время ходьбы — по Яндекс Картам на 10.10.2026.'.cased, style: T.caption.copyWith(color: c.muted)),
        ]),
      ),
    );
  }
}
