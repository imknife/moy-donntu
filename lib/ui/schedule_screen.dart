import 'package:flutter/material.dart';

import '../data/app_controller.dart';
import '../data/schedule_model.dart';
import '../data/resources.dart';
import '../data/specs.dart';
import '../data/teacher_package.dart';
import '../domain/directory.dart';
import '../domain/models.dart';
import '../domain/schedule.dart';
import '../domain/time_utils.dart';
import 'day_chips.dart';
import 'day_pager.dart';
import 'derived.dart';
import 'group_picker.dart';
import 'icons.dart';
import 'motion.dart';
import 'notices_page.dart';
import 'schedule_filter.dart';
import 'schedule_header_parts.dart';
import 'scope.dart';
import 'schedule_env.dart';
import 'theme.dart';
import 'week_month.dart';
import 'type_settings.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, required this.controller, this.previewGroup});
  final AppController controller;
  final String? previewGroup;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  AppController get _c => widget.controller;
  late final ValueNotifier<DateTime> _selected = ValueNotifier(_c.clock.value.today);
  late final ValueNotifier<int> _mode = ValueNotifier(widget.previewGroup == null ? _c.store.prefs.value.mode : 0);
  final ValueNotifier<ScheduleModel?> _previewModel = ValueNotifier(null);
  Resource<GroupPackage>? _previewResource;

  final ValueNotifier<ScheduleModel?> _teacherModel = ValueNotifier(null);
  Resource<List<SharedLesson>>? _teacherResource;
  String _teacherName = '';
  int _teacherSignature = 0;

  bool get _teacherMode => !_preview && _c.store.prefs.value.activeTeacher.isNotEmpty;

  Listenable get _sourceListenable => Listenable.merge([_c.model, _previewModel, _teacherModel, _c.store.prefs]);

  ScheduleModel? _readSource() {
    if (_preview) return _previewModel.value;
    if (_teacherMode) return _teacherModel.value;
    return _c.model.value;
  }

  void _syncTeacher() {
    final name = _preview ? '' : _c.store.prefs.value.activeTeacher;
    if (name == _teacherName) return;
    _teacherResource?.removeListener(_onTeacher);
    _teacherName = name;
    _teacherSignature = 0;
    _teacherModel.value = null;
    if (name.isEmpty) {
      _teacherResource = null;
      return;
    }
    _teacherResource = _c.hub.watch(teacherScheduleSpec(name))..addListener(_onTeacher);
    _onTeacher();
  }

  void _onTeacher() {
    final lessons = _teacherResource?.value.data;
    if (lessons == null || _teacherName.isEmpty) return;
    final base = _c.model.value?.pkg;
    final signature = Object.hash(base?.semesterStart, base?.calendar?.holidays.length, Object.hashAll([for (final l in lessons) Object.hash(l.day, l.num, l.week, l.subgroup, l.subject, l.kind, Object.hashAll(l.rooms), Object.hashAll(l.groups))]));
    if (signature == _teacherSignature && _teacherModel.value != null) return;
    _teacherSignature = signature;
    _teacherModel.value = ScheduleModel(pkg: teacherPackage(_teacherName, lessons, base), subgroup: 0, names: _c.names, nowInstant: _c.clock.now());
  }

  bool get _preview => widget.previewGroup != null;
  final ValueNotifier<double> _headerHeight = ValueNotifier(190);
  final ValueNotifier<double> _headerShift = ValueNotifier(0);
  final GlobalKey _headerKey = GlobalKey();
  ScheduleModel? _envModel;
  ScheduleEnv? _env;

  @override
  void initState() {
    super.initState();
    _selected.addListener(_resetShift);
    _mode.addListener(_onMode);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    if (_preview) {
      _previewResource = _c.hub.watch(packageSpec(widget.previewGroup!))..addListener(_onPreviewPackage);
      _onPreviewPackage();
    } else {
      _c.selectedDay.addListener(_onPendingDay);
      _onPendingDay();
      _c.store.prefs.addListener(_syncTeacher);
      _c.model.addListener(_onTeacher);
      _syncTeacher();
    }
  }

  void _onPreviewPackage() {
    final pkg = _previewResource?.value.data;
    if (pkg != null && _previewModel.value?.pkg != pkg) {
      _previewModel.value = ScheduleModel(pkg: pkg, subgroup: 0, names: _c.names, nowInstant: _c.clock.now());
    }
  }

  void _onPendingDay() {
    final day = _c.selectedDay.value;
    if (day == null) return;
    _c.selectedDay.value = null;
    _selected.value = day;
    _mode.value = _c.store.prefs.value.mode;
  }

  @override
  void dispose() {
    _previewResource?.removeListener(_onPreviewPackage);
    _c.selectedDay.removeListener(_onPendingDay);
    _c.store.prefs.removeListener(_syncTeacher);
    _c.model.removeListener(_onTeacher);
    _teacherResource?.removeListener(_onTeacher);
    _teacherModel.dispose();
    _previewModel.dispose();
    _selected.dispose();
    _mode.dispose();
    _headerHeight.dispose();
    _headerShift.dispose();
    super.dispose();
  }

  void _resetShift() {
    if (_headerShift.value != 0) _headerShift.value = 0;
  }

  void _onMode() {
    _resetShift();
    if (!_preview) _c.store.setPrefs((p) => p.copyWith(mode: _mode.value));
  }

  void _measure() {
    final box = _headerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    if ((box.size.height - _headerHeight.value).abs() > 0.5) _headerHeight.value = box.size.height;
  }

  ScheduleEnv _envFor(ScheduleModel model) {
    if (_envModel == model && _env != null) return _env!;
    _envModel = model;
    return _env = ScheduleEnv(
      model: model,
      store: _c.store,
      clock: _c.clock,
      selected: _selected,
      headerHeight: _headerHeight,
      headerShift: _headerShift,
      openLesson: (row) => _openLesson(row.date, row.item.key),
      openCancelled: (row) => _openLesson(row.date, cancelledKey(row.lesson.num)),
      openDay: _openDay,
      motion: context.motionEnabled,
    );
  }

  void _openLesson(DateTime date, String key) {
    if (_teacherMode) {
      final lesson = _teacherModel.value?.findLesson(date, key)?.lesson;
      final group = lesson?.stream.firstOrNull?.code;
      if (lesson == null || group == null) return;
      context.open('lesson', {'date': ymd(date), 'group': group, 'sub': '${lesson.subgroup}', 'slot': '0', 'key': key});
      return;
    }
    final group = widget.previewGroup ?? _c.store.selection.value.group;
    final sub = _preview ? 0 : _c.store.selection.value.subgroup;
    context.open('lesson', {'date': ymd(date), 'group': group, 'sub': '$sub', 'slot': '0', 'key': key});
  }

  void _openDay(DateTime day) {
    _selected.value = day;
    _mode.value = 0;
  }

  void _step(int step) {
    final d = _selected.value;
    if (_mode.value == 2) {
      final first = DateTime.utc(d.year, d.month + step, 1);
      final last = DateTime.utc(first.year, first.month + 1, 0).day;
      _selected.value = DateTime.utc(first.year, first.month, d.day < last ? d.day : last);
    } else {
      _selected.value = addDays(d, 7 * step);
    }
  }

  void _openPicker() => showGroupSheet(context, _c);

  bool _awayFromToday() {
    final now = _c.clock.value.today;
    final d = _selected.value;
    return switch (_mode.value) {
      2 => d.year != now.year || d.month != now.month,
      1 => startOfIsoWeek(d) != startOfIsoWeek(now),
      _ => !sameDay(d, now),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Material(
      color: c.background,
      child: SafeArea(
        bottom: false,
        child: Derived<ScheduleModel?>(
          listenable: _sourceListenable,
          read: _readSource,
          builder: (context, model) => model == null ? (_teacherMode ? const _TeacherLoading() : _NoGroup(onPick: _openPicker)) : _content(context, model),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, ScheduleModel model) {
    final env = _envFor(model);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final c = context.pal;
    return Stack(
      children: [
        Positioned.fill(
          child: Derived<int>(
            listenable: _mode,
            read: () => _mode.value,
            builder: (context, mode) => switch (mode) {
              0 => Derived<(bool, bool, String, bool)>(
                  listenable: _c.store.prefs,
                  read: () {
                    final p = _c.store.prefs.value;
                    return (p.hidePast, p.showCancelled, p.hiddenKinds.join(','), p.showGaps);
                  },
                  builder: (context, flags) => DayPager(
                    key: ValueKey(model),
                    env: env,
                    hidePast: flags.$1,
                    showCancelled: flags.$2,
                    hiddenKinds: flags.$3.isEmpty ? const {} : flags.$3.split(',').toSet(),
                    showGaps: flags.$4,
                  ),
                ),
              1 => WeekView(env: env),
              _ => MonthView(env: env),
            },
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<double>(
            valueListenable: _headerShift,
            builder: (context, shift, child) => Transform.translate(offset: Offset(0, -shift), child: child),
            child: NotificationListener<SizeChangedLayoutNotification>(
              onNotification: (_) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
                return true;
              },
              child: SizeChangedLayoutNotifier(
                child: Container(key: _headerKey, color: c.background, child: _header(context, model)),
              ),
            ),
          ),
        ),
        _todayPop(c),
      ],
    );
  }

  Widget _header(BuildContext context, ScheduleModel model) {
    final c = context.pal;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _titleRow(context, c),
        _infoRow(context, c, model),
        if (_preview && widget.previewGroup != _c.store.selection.value.group) _previewNotice(context, c),
        _controlsRow(context),
        Derived<bool>(
          listenable: _mode,
          read: () => _mode.value == 0,
          builder: (context, day) => day ? DayChips(env: _env!) : const SizedBox.shrink(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _titleRow(BuildContext context, Pal c) {
    Widget action(String label, String icon, VoidCallback onTap) => Tap(label: label, onTap: onTap, child: SizedBox(width: 44, height: 40, child: Center(child: AppIcon(icon, size: 22, color: c.text))));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 5, 0),
      child: Row(
        children: [
          Expanded(
            child: Derived<DateTime>(
              listenable: _selected,
              read: () => _selected.value,
              builder: (context, d) => FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${d.day} ', style: T.title.copyWith(color: c.text)),
                    TextSpan(text: monthsGenitive[d.month - 1].cased, style: T.title.copyWith(color: c.link)),
                  ]),
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ),
          ),
          if (_preview)
            action('Закрыть', 'close', () => Navigator.of(context).maybePop())
          else ...[
            action('Поиск', 'search', () => context.open('search')),
            const NoticeBell(),
            action('Что показывать', 'filter', () => showScheduleFilter(context, _c)),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, Pal c, ScheduleModel model) {
    final style = T.caption.copyWith(height: 16 / 13, color: c.muted);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
      child: Derived<(String, String, String)>(
        listenable: Listenable.merge([_selected, _mode, _c.clock, _c.store.selection, _c.store.prefs]),
        read: () {
          final d = _selected.value;
          final week = weekTypeFor(d, model.pkg.semesterStart) == 'UPPER' ? 'верхняя' : 'нижняя';
          final sel = _c.store.selection.value;
          final teacher = _teacherMode ? _c.store.prefs.value.activeTeacher : '';
          final group = _preview ? widget.previewGroup! : teacher.isNotEmpty ? fullTeacherName(teacher, _c.names) : '${sel.group}${sel.subgroup > 0 ? ' · ${sel.subgroup} п/г' : ''}';
          return ('${dayNames[isoDay(d)]} · $week неделя', '${dayShort[isoDay(d)]} · $week', group);
        },
        builder: (context, info) => LayoutBuilder(
          builder: (context, box) {
            final (full, short, group) = info;
            final scaler = MediaQuery.textScalerOf(context);
            double measure(String text, TextStyle style) {
              final painter = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, textScaler: scaler, maxLines: 1)..layout();
              return painter.width;
            }

            final groupWidth = measure(group, style.copyWith(fontWeight: FontWeight.w500)) + 16 + 16 + 2 + 2;
            final fits = measure(full, style) + 8 + groupWidth <= box.maxWidth;
            return Row(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: box.maxWidth * 0.62),
                  child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(fits ? full : short, maxLines: 1, softWrap: false, style: style)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: _groupButton(c, style, group)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _todayPop(Pal c) => Positioned(
        right: 16,
        bottom: 16,
        child: Derived<bool>(
          listenable: Listenable.merge([_selected, _mode, _c.clock]),
          read: _awayFromToday,
          builder: (context, away) => AnimatedSwitcher(
            duration: MotionPolicy.enabled ? const Duration(milliseconds: 220) : Duration.zero,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(position: Tween(begin: const Offset(0, 0.6), end: Offset.zero).animate(animation), child: child),
            ),
            child: away ? KeyedSubtree(key: const ValueKey('today'), child: _todayPill(c)) : const SizedBox.shrink(key: ValueKey('none')),
          ),
        ),
      );

  Widget _todayPill(Pal c) => Tap(
        label: 'Вернуться к сегодняшнему дню',
        onTap: () => _selected.value = _c.clock.value.today,
        child: Container(
          height: 44,
          padding: const EdgeInsets.fromLTRB(14, 0, 18, 0),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: c.hairline),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: c.dark ? 0.45 : 0.14), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            AppIcon('schedule', size: 18, color: c.link),
            const SizedBox(width: 8),
            Text('Сегодня'.cased, maxLines: 1, softWrap: false, style: T.subject.copyWith(color: c.text)),
          ]),
        ),
      );

  Widget _groupButton(Pal c, TextStyle style, String group) {
    final label = style.copyWith(fontWeight: FontWeight.w500, color: c.text);
    final box = Container(
      height: 28,
      padding: EdgeInsets.only(left: 8, right: _preview ? 8 : 4),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: c.hairline)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: Text(group, maxLines: 1, overflow: TextOverflow.ellipsis, style: label)),
        if (!_preview) ...[
          const SizedBox(width: 2),
          AppIcon('chevronDown', size: 16, color: c.muted),
        ],
      ]),
    );
    if (_preview) return box;
    return Tap(label: 'Расписание', onTap: _openPicker, child: box);
  }

  Widget _previewNotice(BuildContext context, Pal c) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Expanded(child: Text('Чужая группа · ваша ${_c.store.selection.value.group}'.cased, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.caption.copyWith(color: c.muted))),
              const SizedBox(width: 8),
              Tap(
                label: 'Сделать ${widget.previewGroup} моей группой',
                onTap: () async {
                  try {
                    await _c.chooseGroup(widget.previewGroup!, subgroup: 0);
                  } catch (_) {
                    return;
                  }
                  if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                },
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), child: Text('Сделать моей'.cased, style: T.captionSemi.copyWith(color: c.link))),
              ),
            ],
          ),
        ),
      );

  Widget _controlsRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 4, 2),
      child: LayoutBuilder(
        builder: (context, box) => SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Derived<int>(
                listenable: _mode,
                read: () => _mode.value,
                builder: (context, m) => ModeSwitch(value: m, onChanged: (i) => _mode.value = i, compact: box.maxWidth < 360),
              ),
              PeriodNav(selected: _selected, mode: _mode, onStep: _step, compact: box.maxWidth < 360),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherLoading extends StatelessWidget {
  const _TeacherLoading();

  @override
  Widget build(BuildContext context) => Center(child: Text('Загружаем расписание преподавателя'.cased, style: T.body.copyWith(color: context.pal.muted)));
}

class _NoGroup extends StatelessWidget {
  const _NoGroup({required this.onPick});
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Выберите группу, чтобы увидеть расписание'.cased, style: T.body.copyWith(color: c.text)),
          const SizedBox(height: 12),
          Tap(onTap: onPick, child: Text('Выбрать группу'.cased, style: T.bodyLink.copyWith(color: c.link))),
        ],
      ),
    );
  }
}
