import 'package:flutter/material.dart';

import '../data/specs.dart';
import '../data/store.dart';
import '../domain/campus.dart';
import '../domain/directory.dart';
import '../domain/models.dart';
import '../domain/room_display.dart';
import '../domain/schedule.dart';
import '../domain/time_utils.dart';
import 'common.dart';
import 'day_swipe.dart';
import 'derived.dart';
import 'icons.dart';
import 'lesson_preview.dart';
import 'sheet.dart';
import 'lesson_card.dart';
import 'not_found.dart';
import 'scope.dart';
import 'theme.dart';
import 'widgets.dart';
import 'type_settings.dart';

bool _matches(String text, String q) => q.isEmpty || text.toLowerCase().contains(q);

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _query = TextEditingController();
  String _kind = 'Преподаватели';
  static const _kinds = ['Преподаватели', 'Аудитории', 'Группы'];

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _go(RecentSearch entry) {
    context.app.store.addRecent(entry);
    context.open(entry.page, entry.params);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.pal;
    final today = app.clock.value.today;
    final date = ymd(today);
    final minute = snapToBell(app.clock.value.minute, isoDay(today));
    return PageScaffold(
      title: 'Поиск',
      children: [
        SearchBox(controller: _query, hint: 'Преподаватель, аудитория, группа', autofocus: true),
        const VGap(8),
        ChipRow(options: _kinds, value: _kind, onChanged: (v) => setState(() => _kind = v)),
        const VGap(8),
        ListenableBuilder(
          listenable: Listenable.merge([_query, app.store.recents]),
          builder: (context, _) {
            final q = _query.text.trim().toLowerCase();
            final recents = app.store.recents.value;
            Widget recentRows() => RowsCard(children: [
                  for (final r in recents) MenuRow(icon: r.page == 'room' ? 'room' : (r.page == 'group' ? 'people' : 'teacher'), title: r.title, onTap: () => _go(r)),
                ]);
            if (q.isEmpty && _kind == 'Аудитории') {
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SectionHead(title: 'Свободно сейчас', link: 'Выбрать время →', onTap: () => context.open('rooms')),
                ResourceView<FreeRooms>(resource: app.hub.watch(freeRoomsSpec(date, minute)), builder: (context, data) => FreeRoomGrid(rooms: data.free, date: date)),
                const SectionLabel('Недавнее'),
                if (recents.isEmpty) Text('Здесь появятся аудитории, преподаватели и группы, которые вы открывали.'.cased, style: T.caption.copyWith(color: c.muted)) else recentRows(),
                const VGap(8),
                PrimaryButton(label: 'Сохранённые преподаватели', secondary: true, onTap: () => context.open('teachers')),
              ]);
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (q.isEmpty && recents.isNotEmpty) ...[const SectionLabel('Недавнее'), recentRows(), SectionLabel(_kind)],
              if (_kind == 'Группы') _groupHits(context, q),
              if (_kind == 'Преподаватели') _teacherHits(context, q),
              if (_kind == 'Аудитории') _roomHits(context, q, date),
            ]);
          },
        ),
      ],
    );
  }

  Widget _groupHits(BuildContext context, String q) {
    final groups = [for (final g in context.app.groups.value) if (g.code.toLowerCase().contains(q)) g];
    if (groups.isEmpty) return const NothingFound(hint: 'Группы с таким названием нет. Введите код группы, например ПИ-25а.');
    return RowsCard(children: [for (final g in groups) MenuRow(icon: 'people', title: g.code, detail: g.faculty, onTap: () => _go(RecentSearch(g.code, 'group', {'group': g.code})))]);
  }

  Widget _teacherHits(BuildContext context, String q) {
    final app = context.app;
    return ResourceView<List<TeacherHit>>(
      resource: app.hub.watch(teachersSpec()),
      builder: (context, all) {
        final hits = [for (final t in all) if (_matches('${t.name} ${fullTeacherName(t.name, app.names)}', q)) t];
        if (hits.isEmpty) return const NothingFound(hint: 'Преподавателя с такой фамилией нет в опубликованных расписаниях. Попробуйте ввести только фамилию.');
        return RowsCard(children: [
          for (final t in hits.take(80))
            MenuRow(
              icon: 'teacher',
              title: fullTeacherName(t.name, app.names),
              detail: [rankLabel(t.rank), '${pluralLessons(t.lessons)} в неделю'].where((e) => e.isNotEmpty).join(' · '),
              onTap: () => _go(RecentSearch(t.name, 'teacher', {'name': t.name})),
            ),
        ]);
      },
    );
  }

  Widget _roomHits(BuildContext context, String q, String date) {
    return ResourceView<FreeRooms>(
      resource: context.app.hub.watch(roomsSpec()),
      builder: (context, data) {
        final hits = [for (final r in data.free) if (_matches(r.label, q)) r];
        if (hits.isEmpty) return const NothingFound(hint: 'Такой аудитории нет в расписаниях. Введите номер в формате 4.418.');
        return RowsCard(children: [
          for (final r in hits.take(80))
            MenuRow(
              icon: 'room',
              title: 'Аудитория ${r.label}',
              detail: 'Корпус ${r.building}${r.floor != null && r.floor != 0 ? ' · ${r.floor} этаж' : ''}',
              onTap: () => _go(RecentSearch('Аудитория ${r.label}', 'room', {'room': r.label, 'date': date})),
            ),
        ]);
      },
    );
  }
}

class FreeRoomGrid extends StatelessWidget {
  const FreeRoomGrid({super.key, required this.rooms, required this.date});
  final List<FreeRoom> rooms;
  final String date;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final buildings = <int>[];
    for (final r in rooms) {
      if (!buildings.contains(r.building)) buildings.add(r.building);
    }
    if (rooms.isEmpty) return const NothingFound(icon: 'room', hint: 'На выбранное время свободных аудиторий нет. Выберите другую пару, день или корпус.');
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < buildings.length; i++) ...[
            Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 10, bottom: 6), child: Text('Корпус ${buildings[i]}'.cased, style: T.captionSemi.copyWith(color: c.muted))),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final r in rooms.where((x) => x.building == buildings[i]))
                Tap(
                  label: 'Аудитория ${r.label}',
                  onTap: () => context.open('room', {'room': r.label, 'date': date}),
                  child: IntrinsicWidth(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 40, minWidth: 58),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: c.background, borderRadius: BorderRadius.circular(10)),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(r.label, style: T.subject.copyWith(color: c.text, fontSize: 15, height: 18 / 15)),
                        if (r.freeUntil != null) Text('до ${minutesToTime(r.freeUntil!)}'.cased, style: T.micro.copyWith(color: c.muted, fontSize: 10, height: 12 / 10)),
                      ]),
                    ),
                  ),
                ),
            ]),
          ],
        ],
      ),
    );
  }
}

class TeachersPage extends StatefulWidget {
  const TeachersPage({super.key});

  @override
  State<TeachersPage> createState() => _TeachersPageState();
}

class _TeachersPageState extends State<TeachersPage> {
  final TextEditingController _query = TextEditingController();
  int _mode = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return PageScaffold(
      title: 'Преподаватели',
      children: [
        SearchBox(controller: _query, hint: 'Фамилия или имя преподавателя'),
        const VGap(8),
        SegmentedPill(options: const ['Все', 'Сохранённые'], value: _mode, onChanged: (i) => setState(() => _mode = i), height: 36),
        const VGap(8),
        ListenableBuilder(
          listenable: Listenable.merge([_query, app.store.prefs]),
          builder: (context, _) {
            final q = _query.text.trim().toLowerCase();
            if (_mode == 1) {
              final saved = [for (final n in app.store.prefs.value.savedTeachers) if (_matches('$n ${fullTeacherName(n, app.names)}', q)) n];
              if (app.store.prefs.value.savedTeachers.isEmpty) return const EmptyBox(icon: 'teacher', title: 'Сохраните преподавателя на странице его расписания');
              if (saved.isEmpty) return const NothingFound(hint: 'Среди сохранённых такого преподавателя нет. Очистите поиск или переключитесь на «Все».');
              return RowsCard(children: [for (final n in saved) MenuRow(icon: 'teacher', title: fullTeacherName(n, app.names), onTap: () => context.open('teacher', {'name': n}))]);
            }
            return ResourceView<List<TeacherHit>>(
              resource: app.hub.watch(teachersSpec()),
              builder: (context, all) {
                final rows = [for (final t in all) if (_matches('${t.name} ${fullTeacherName(t.name, app.names)}', q)) t];
                if (rows.isEmpty) return const NothingFound(hint: 'Преподавателя с такой фамилией нет в опубликованных расписаниях. Попробуйте ввести только фамилию.');
                return SurfaceCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(children: [
                    for (final t in rows.take(120))
                      MenuRow(
                        icon: 'teacher',
                        title: fullTeacherName(t.name, app.names),
                        detail: [rankLabel(t.rank), '${t.lessons} ${plural(t.lessons, 'занятие', 'занятия', 'занятий')}'].where((e) => e.isNotEmpty).join(' · '),
                        onTap: () => context.open('teacher', {'name': t.name}),
                      ),
                  ]),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class TeacherPage extends StatefulWidget {
  const TeacherPage({super.key, required this.name});
  final String name;

  @override
  State<TeacherPage> createState() => _TeacherPageState();
}

class _TeacherPageState extends State<TeacherPage> {
  int _mode = 0;
  late int _day = isoDay(context.app.clock.value.today);
  String? _parity;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.pal;
    final parity = _parity ?? weekTypeFor(app.clock.value.today, app.model.value?.pkg.semesterStart);
    return ValueListenableBuilder<Prefs>(
      valueListenable: app.store.prefs,
      builder: (context, prefs, _) {
        final saved = prefs.savedTeachers.contains(widget.name);
        return PageScaffold(
          title: fullTeacherName(widget.name, app.names),
          children: [
            Row(children: [
              Expanded(child: SegmentedPill(options: const ['День', 'Неделя'], value: _mode, onChanged: (i) => setState(() => _mode = i), height: 34)),
              const SizedBox(width: 8),
              PillButton(label: parity == 'UPPER' ? 'Верхняя' : 'Нижняя', onTap: () => setState(() => _parity = parity == 'UPPER' ? 'LOWER' : 'UPPER')),
              const SizedBox(width: 4),
              Tap(
                label: saved ? 'Убрать из сохранённых' : 'Сохранить преподавателя',
                onTap: () => app.store.setPrefs((p) => p.copyWith(savedTeachers: saved ? [for (final n in p.savedTeachers) if (n != widget.name) n] : [...p.savedTeachers, widget.name])),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: saved ? c.tint : c.soft, borderRadius: BorderRadius.circular(14)),
                  alignment: Alignment.center,
                  child: AppIcon('star', size: 20, color: saved ? c.link : c.text),
                ),
              ),
            ]),
            if (_mode == 0) ...[
              const VGap(8),
              SegmentedPill(options: dayShort.sublist(1), value: _day - 1, onChanged: (i) => setState(() => _day = i + 1), height: 34),
            ],
            const VGap(8),
            DaySwipe(
              onStep: (step) => setState(() {
                if (_mode == 1) {
                  _parity = parity == 'UPPER' ? 'LOWER' : 'UPPER';
                  return;
                }
                final next = _day + step;
                if (next < 1 || next > 7) _parity = parity == 'UPPER' ? 'LOWER' : 'UPPER';
                _day = (next - 1) % 7 + 1;
              }),
              child: ResourceView<List<SharedLesson>>(
                resource: app.hub.watch(teacherScheduleSpec(widget.name)),
                builder: (context, lessons) {
                  final shown = [for (final l in lessons) if ((_mode == 1 || l.day == _day) && (l.week == 'BOTH' || l.week == parity)) l];
                  if (lessons.isEmpty) return const NothingFound(icon: 'teacher', hint: 'У этого преподавателя нет опубликованных занятий. Загляните позже или вернитесь к поиску.');
                  if (shown.isEmpty) {
                    return NothingFound(icon: 'sun', hint: _mode == 1 ? 'На выбранной неделе пар нет. Переключите неделю кнопкой «Верхняя» или «Нижняя».' : 'В этот день пар нет. Выберите другой день или переключите неделю.');
                  }
                  return SharedLessonList(lessons: shown);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class SharedLessonList extends StatelessWidget {
  const SharedLessonList({super.key, required this.lessons});
  final List<SharedLesson> lessons;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    if (lessons.isEmpty) return Text('В этот день занятий нет'.cased, style: T.body.copyWith(color: c.muted));
    return Column(children: [
      for (final l in lessons)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SurfaceCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${dayShort[l.day]} · ${l.num}-я пара · ${_startOf(l)}'.cased, style: T.caption.copyWith(color: c.muted)),
              const SizedBox(height: 4),
              Text(l.subject, style: T.heading.copyWith(color: c.text)),
              const SizedBox(height: 4),
              Row(children: [KindChip(kind: l.kind), const SizedBox(width: 8), Expanded(child: Text(l.rooms.isEmpty ? 'Аудитория уточняется' : l.rooms.join(', '), style: T.caption.copyWith(color: c.muted)))]),
              if (l.groups.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(l.groups.join(' · '), style: T.caption.copyWith(color: c.muted))),
              if (l.teachers.isNotEmpty) Text(l.teachers.join(', '), style: T.caption.copyWith(color: c.muted)),
            ]),
          ),
        ),
    ]);
  }

  String _startOf(SharedLesson l) {
    for (final b in bellsForDay(defaultBells, l.day)) {
      if (b.num == l.num) return shortTime(b.start);
    }
    return '';
  }
}

class RoomsPage extends StatefulWidget {
  const RoomsPage({super.key, this.building});
  final String? building;

  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  int _mode = 0;
  int _dayIndex = 0;
  int? _pair;
  late String _building = campusBuildings.any((b) => b.rooms && b.id == widget.building) ? 'Корпус ${widget.building}' : 'Все корпуса';

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final today = app.clock.value.today;
    final minuteNow = app.clock.value.minute;
    final days = [for (var i = 0; i < 7; i++) addDays(today, i)];
    final dayLabels = [for (var i = 0; i < 7; i++) i == 0 ? 'Сегодня' : (i == 1 ? 'Завтра' : '${dayShort[isoDay(days[i])]} ${days[i].day}')];
    final date = days[_dayIndex];
    final bells = bellsForDay(defaultBells, isoDay(date));
    final pairLabels = [for (final b in bells) '${b.num} пара · ${shortTime(b.start)}'];
    Bell? chosen;
    if (_pair != null && _pair! < bells.length) {
      chosen = bells[_pair!];
    } else if (sameDay(date, today)) {
      for (final b in bells) {
        if (b.endMinutes > minuteNow) {
          chosen = b;
          break;
        }
      }
    }
    chosen ??= bells.first;
    final actualDate = _mode == 0 ? ymd(today) : ymd(date);
    final minute = _mode == 0 ? snapToBell(minuteNow, isoDay(today)) : chosen.startMinutes;
    final buildingId = _building.startsWith('Корпус ') ? _building.substring(7) : null;
    final buildingNames = [for (final b in campusBuildings) if (b.rooms) b.id];
    final spec = freeRoomsSpec(actualDate, minute, building: buildingId == null ? null : int.tryParse(buildingId));
    return PageScaffold(
      title: 'Свободные аудитории',
      children: [
        SegmentedPill(options: const ['Сейчас', 'На время'], value: _mode, onChanged: (i) => setState(() => _mode = i), height: 34),
        const VGap(10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          SelectorPill(
            label: 'Корпус',
            value: _building == 'Все корпуса' ? 'Все корпуса' : _building,
            onTap: () async {
              final options = ['Все корпуса', for (final b in buildingNames) 'Корпус $b'];
              final i = await showChoiceSheet(context, title: 'Корпус', options: options, selected: options.indexOf(_building));
              if (i != null) setState(() => _building = options[i]);
            },
          ),
          if (_mode == 1) ...[
            SelectorPill(
              label: 'День',
              value: dayLabels[_dayIndex],
              onTap: () async {
                final i = await showChoiceSheet(context, title: 'День', options: dayLabels, selected: _dayIndex);
                if (i != null) {
                  setState(() {
                    _dayIndex = i;
                    _pair = null;
                  });
                }
              },
            ),
            SelectorPill(
              label: 'Пара',
              value: pairLabels[bells.indexOf(chosen)],
              onTap: () async {
                final i = await showChoiceSheet(context, title: 'Пара', options: pairLabels, selected: bells.indexOf(chosen!));
                if (i != null) setState(() => _pair = i);
              },
            ),
          ],
        ]),
        SectionLabel(_mode == 0 ? 'Свободно сейчас' : 'Свободно ${dayLabels[_dayIndex].toLowerCase()}, ${chosen.num} пара (${shortTime(chosen.start)})'),
        ResourceView<FreeRooms>(keepPrevious: true, resource: app.hub.watch(spec), builder: (context, data) => FreeRoomGrid(rooms: data.free, date: actualDate)),
      ],
    );
  }
}

class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.date, required this.today, required this.onSelect});
  final DateTime date;
  final DateTime today;
  final void Function(DateTime day) onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final monday = startOfIsoWeek(date);
    Widget arrow(String icon, int step) => Tap(
          label: step < 0 ? 'Предыдущая неделя' : 'Следующая неделя',
          onTap: () => onSelect(addDays(date, 7 * step)),
          child: SizedBox(width: 40, height: 40, child: Center(child: AppIcon(icon, size: 18, color: c.text))),
        );
    return Row(children: [
      arrow('chevronLeft', -1),
      for (var i = 0; i < 7; i++)
        Expanded(
          child: Tap(
            label: '${dayShort[i + 1]}, ${addDays(monday, i).day}',
            onTap: () => onSelect(addDays(monday, i)),
            child: Container(
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: sameDay(addDays(monday, i), date) ? c.tint : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: sameDay(addDays(monday, i), today) && !sameDay(addDays(monday, i), date) ? c.link : Colors.transparent),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(dayShort[i + 1], style: T.dayName.copyWith(color: c.muted)),
                Text('${addDays(monday, i).day}', style: (sameDay(addDays(monday, i), date) ? T.dayNumSel : T.dayNum).copyWith(color: sameDay(addDays(monday, i), date) ? c.link : c.text)),
              ]),
            ),
          ),
        ),
      arrow('chevron', 1),
    ]);
  }
}

bool _overlaps(TimeSpan? picked, Bell bell) => picked != null && bell.startMinutes < picked.to && bell.endMinutes > picked.from;

class RoomPage extends StatefulWidget {
  const RoomPage({super.key, required this.room, this.date, this.group});
  final String room;
  final String? date;
  final String? group;

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  late DateTime _date = parseYmd(widget.date ?? '') ?? context.app.clock.value.today;
  TimeSpan? _picked;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.pal;
    final preferred = widget.group ?? app.store.selection.value.group;
    return PageScaffold(
      title: 'Аудитория ${widget.room}',
      children: [
        Derived<({DateTime today, int minute})>(
          listenable: app.clock,
          read: () => app.clock.value,
          builder: (context, now) => _body(context, now.today, now.minute, c, preferred),
        ),
      ],
    );
  }

  Widget _body(BuildContext context, DateTime today, int minute, Pal c, String preferred) {
    final app = context.app;
    final isToday = sameDay(_date, today);
    return ResourceView<RoomDay>(
      keepPrevious: true,
      resource: app.hub.watch(roomDaySpec(widget.room, ymd(_date))),
      builder: (context, data) {
        final grouped = groupRoomLessons(data.lessons);
        final agenda = roomAgenda(roomSlots(bellsForDay(defaultBells, isoDay(_date)), grouped));
        final status = data.known && isToday ? roomStatus(data.busy, minute) : null;
        final building = data.room?.building;
        final cabinet = cabinetOf(data.room?.room, data.room?.floor);
        final place = [
          building != null ? 'Корпус $building' : 'Корпус уточняется',
          if (data.room?.floor != null) data.room!.floor == 0 ? 'цокольный этаж' : '${data.room!.floor} этаж',
          if (cabinet != null) 'кабинет $cabinet',
        ].join(' · ');
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: c.link, borderRadius: BorderRadius.circular(16)),
              alignment: Alignment.center,
              child: Text('${building ?? '?'}', style: T.display.copyWith(color: c.onLink, fontSize: 28, height: 1.2)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(place, style: T.subject.copyWith(color: c.text, fontSize: 16)),
                if (status != null)
                  Row(children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: status.busy ? c.axis : c.link)),
                    const SizedBox(width: 6),
                    Text(
                      status.busy ? 'Занята до ${minutesToTime(status.until!)}' : (status.until != null ? 'Свободна до ${minutesToTime(status.until!)}' : 'Свободна до конца дня'),
                      style: T.captionMedium.copyWith(color: status.busy ? c.muted : c.link),
                    ),
                  ]),
              ]),
            ),
          ]),
          const VGap(8),
          WeekStrip(date: _date, today: today, onSelect: (d) => setState(() {
                _date = d;
                _picked = null;
              })),
          const VGap(8),
          DaySwipe(
            onStep: (step) => setState(() {
              _date = addDays(_date, step);
              _picked = null;
            }),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!data.known)
                const NothingFound(icon: 'room', hint: 'Этой аудитории нет в расписаниях групп. Проверьте номер или найдите другую через поиск.')
              else if (grouped.isEmpty)
                SurfaceCard(child: Text('Свободна весь день'.cased))
              else ...[
                SurfaceCard(child: RoomTimeline(data: data, grouped: grouped, minute: isToday ? minute : null, picked: _picked, onPick: (v) => setState(() => _picked = (_picked?.from == v.from && _picked?.to == v.to) ? null : v))),
                const VGap(8),
                for (final item in agenda)
                  switch (item) {
                    AgendaBusy() => _BusyRow(
                        bell: item.bell,
                        row: item.row,
                        date: _date,
                        preferredGroup: preferred,
                        live: isToday && item.bell.startMinutes <= minute && item.bell.endMinutes > minute,
                        picked: _overlaps(_picked, item.bell),
                      ),
                    AgendaFree() => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(children: [
                          SizedBox(width: 112, child: Text(item.toEnd ? 'с ${shortTime(item.from)}' : '${shortTime(item.from)}–${shortTime(item.to)}', style: T.body.copyWith(color: c.muted))),
                          Expanded(child: Text(item.toEnd ? 'Свободно до конца дня' : 'Свободно', style: T.body.copyWith(color: c.muted))),
                        ]),
                      ),
                  },
              ],
              if (building != null && app.features.value.campus) ...[const VGap(8), PrimaryButton(label: 'Корпус на карте', secondary: true, onTap: () => context.open('campus', {'building': '$building'}))],
            ]),
          ),
        ]);
      },
    );
  }
}

class RoomTimeline extends StatelessWidget {
  const RoomTimeline({super.key, required this.data, required this.grouped, required this.minute, required this.picked, required this.onPick});
  final RoomDay data;
  final List<RoomLessonGroup> grouped;
  final int? minute;
  final TimeSpan? picked;
  final void Function(TimeSpan value) onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final range = (data.to - data.from) < 1 ? 1 : data.to - data.from;
    final conflicts = <TimeSpan>[];
    for (var i = 0; i < grouped.length; i++) {
      for (var j = i + 1; j < grouped.length; j++) {
        final from = grouped[i].item.bell.startMinutes > grouped[j].item.bell.startMinutes ? grouped[i].item.bell.startMinutes : grouped[j].item.bell.startMinutes;
        final to = grouped[i].item.bell.endMinutes < grouped[j].item.bell.endMinutes ? grouped[i].item.bell.endMinutes : grouped[j].item.bell.endMinutes;
        if (from < to) conflicts.add(TimeSpan(from, to));
      }
    }
    final ticks = roomHourTicks(data.from, data.to);
    final labels = [for (var i = 0; i < ticks.length; i++) if (i == 0 || i == ticks.length - 1 || (ticks[i] % 240 == 0 && ticks[i] - ticks.first >= 90 && ticks.last - ticks[i] >= 90)) ticks[i]];
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      double left(int v) => w * (v - data.from) / range;
      double width(int a, int b) => w * (b - a) / range;
      return Column(children: [
        SizedBox(
          height: 36,
          child: Stack(children: [
            Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(12)))),
            for (final b in data.busy)
              Positioned(
                left: left(b.from),
                width: width(b.from, b.to),
                top: 4,
                bottom: 4,
                child: Tap(
                  label: 'Занято ${minutesToTime(b.from)}–${minutesToTime(b.to)}, показать занятие',
                  onTap: () => onPick(b),
                  child: Container(
                    decoration: BoxDecoration(color: c.link, borderRadius: BorderRadius.circular(8), border: picked?.from == b.from && picked?.to == b.to ? Border.all(color: c.text, width: 2) : null),
                  ),
                ),
              ),
            for (final b in conflicts)
              Positioned(left: left(b.from), width: width(b.from, b.to), top: 4, bottom: 4, child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(color: c.danger, borderRadius: BorderRadius.circular(8))))),
            if (minute != null && minute! >= data.from && minute! <= data.to)
              Positioned(left: left(minute!), top: 0, bottom: 0, width: 2, child: IgnorePointer(child: ColoredBox(color: c.text))),
          ]),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 18,
          child: Stack(children: [
            for (var i = 0; i < labels.length; i++)
              Positioned(
                left: (i == 0 ? left(labels[i]) : (i == labels.length - 1 ? left(labels[i]) - 44 : left(labels[i]) - 22)).clamp(0.0, w - 44),
                width: 44,
                child: Text(minutesToTime(labels[i]), textAlign: i == 0 ? TextAlign.left : (i == labels.length - 1 ? TextAlign.right : TextAlign.center), style: T.micro.copyWith(color: c.muted, fontSize: 11)),
              ),
          ]),
        ),
      ]);
    });
  }
}

class _BusyRow extends StatelessWidget {
  const _BusyRow({required this.bell, required this.row, required this.date, required this.preferredGroup, required this.live, required this.picked});
  final Bell bell;
  final RoomLessonGroup row;
  final DateTime date;
  final String preferredGroup;
  final bool live;
  final bool picked;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final source = row.sources.firstWhere((s) => s.group == preferredGroup, orElse: () => row.sources.first);
    final groups = row.sources.map((s) => '${s.group}${s.item.lesson.subgroup != 0 ? ' · ${s.item.lesson.subgroup} подгр.' : ''}').join(', ');
    return Tap(
      label: '${shortTime(bell.start)}–${shortTime(bell.end)}, ${kindLabel[row.item.lesson.kind]}, ${row.item.lesson.subject}, $groups',
      onTap: () => showLessonPreview(context, date: date, item: source.item, group: source.group, subgroup: source.item.lesson.subgroup, groups: groups),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(color: live ? c.tint : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: picked ? c.link : Colors.transparent, width: 1.5)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 112, child: Text('${shortTime(bell.start)}–${shortTime(bell.end)}', style: T.subject.copyWith(color: c.text, fontFeatures: const [FontFeature.tabularFigures()]))),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(row.item.lesson.subject, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.subject.copyWith(color: c.text)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [KindChip(kind: row.item.lesson.kind), Text(groups, style: T.caption.copyWith(color: c.muted))]),
              if (row.conflict) Text('В это же время здесь ещё одно занятие'.cased, style: T.caption.copyWith(color: c.danger)),
            ]),
          ),
        ]),
      ),
    );
  }
}
