import 'package:flutter/material.dart';

import '../data/schedule_model.dart';
import '../domain/time_utils.dart';
import 'derived.dart';
import 'icons.dart';
import 'lesson_card.dart';
import 'schedule_env.dart';
import 'theme.dart';

final DateTime pagerAnchor = DateTime.utc(2020, 1, 1);
const int pagerCount = 365 * 16;

int pageOf(DateTime d) => daysBetween(pagerAnchor, d);
DateTime dateOfPage(int i) => addDays(pagerAnchor, i);

class DayPager extends StatefulWidget {
  const DayPager({super.key, required this.env, required this.hidePast, required this.showCancelled, this.hiddenKinds = const {}, this.showGaps = true});
  final ScheduleEnv env;
  final bool hidePast;
  final bool showCancelled;
  final Set<String> hiddenKinds;
  final bool showGaps;

  @override
  State<DayPager> createState() => _DayPagerState();
}

class _DayPagerState extends State<DayPager> {
  late final PageController _controller = PageController(initialPage: pageOf(widget.env.selected.value));
  int _token = 0;
  bool _busy = false;
  bool _internal = false;

  @override
  void initState() {
    super.initState();
    widget.env.selected.addListener(_onSelected);
  }

  @override
  void dispose() {
    widget.env.selected.removeListener(_onSelected);
    _controller.dispose();
    super.dispose();
  }

  int get _current => (_controller.hasClients ? (_controller.page ?? _controller.initialPage.toDouble()) : _controller.initialPage.toDouble()).round();

  void _onSelected() {
    final target = pageOf(widget.env.selected.value);
    if (_internal || !_controller.hasClients || target == _current) return;
    _goto(target);
  }

  Future<void> _goto(int target) async {
    final token = ++_token;
    if (!widget.env.motion) {
      _controller.jumpToPage(target);
      return;
    }
    _busy = true;
    final delta = target - _current;
    if (delta.abs() > 1) _jumpBeside(target, delta.sign);
    await _controller.animateToPage(target, duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic);
    if (token == _token) _busy = false;
  }

  void _jumpBeside(int target, int direction) => _controller.jumpToPage(target - direction);

  void _onPageChanged(int i) {
    if (_busy) return;
    _internal = true;
    widget.env.selected.value = dateOfPage(i);
    _internal = false;
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      itemCount: pagerCount,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, i) => DayPage(date: dateOfPage(i), env: widget.env, hidePast: widget.hidePast, showCancelled: widget.showCancelled, hiddenKinds: widget.hiddenKinds, showGaps: widget.showGaps),
    );
  }
}

class DayPage extends StatelessWidget {
  const DayPage({super.key, required this.date, required this.env, required this.hidePast, required this.showCancelled, this.hiddenKinds = const {}, this.showGaps = true});
  final DateTime date;
  final ScheduleEnv env;
  final bool hidePast;
  final bool showCancelled;
  final Set<String> hiddenKinds;
  final bool showGaps;

  @override
  Widget build(BuildContext context) {
    final isToday = sameDay(date, env.clock.value.today);
    if (hidePast && isToday) {
      return Derived<int>(
        listenable: env.clock,
        read: () => env.model.items(date).where((x) => x.bell.endMinutes > env.clock.value.minute).length,
        builder: (context, _) => _list(env.model.rows(date, showCancelled: showCancelled, hideEndedBefore: env.clock.value.minute), isToday),
      );
    }
    return _list(env.model.rows(date, showCancelled: showCancelled), isToday);
  }

  Widget _list(List<RowSpec> rows, bool isToday) {
    final blocks = _blocks(rows, isToday);
    return ScrollReporter(
      env: env,
      child: ValueListenableBuilder<double>(
        valueListenable: env.headerHeight,
        builder: (context, h, _) => ListView.builder(
          padding: EdgeInsets.fromLTRB(8, h, 8, 76),
          itemCount: blocks.length,
          itemBuilder: (context, i) => Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 8), child: blocks[i]),
        ),
      ),
    );
  }

  List<Widget> _blocks(List<RowSpec> rows, bool isToday) {
    final blocks = <Widget>[];
    var island = <Widget>[];
    RowSpec? previous;
    void flush() {
      if (island.isNotEmpty) blocks.add(_Island(children: island));
      island = [];
    }

    for (final row in rows) {
      if (row is CardRow && hiddenKinds.contains(row.item.lesson.kind)) continue;
      if (row is GapRow && !showGaps) continue;
      switch (row) {
        case CardRow():
          if (previous is CardRow) island.add(const _Hairline());
          island.add(LessonCard(
            row: row,
            names: env.model.names,
            clock: env.clock,
            notes: env.store.notes,
            isToday: isToday && sameDay(row.date, date),
            onOpen: env.openLesson,
          ));
        case GapRow():
          island.add(GapTile(minutes: row.minutes));
        case EmptyRow():
          flush();
          blocks.add(_Empty(row));
        case CancelledRow():
          flush();
          blocks.add(CancelledCard(row: row, onOpen: env.openCancelled));
      }
      previous = row;
    }
    flush();
    return blocks;
  }
}

class _Island extends StatelessWidget {
  const _Island({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Divider(height: 1, thickness: 1, color: context.pal.hairline),
      );
}

class _Empty extends StatelessWidget {
  const _Empty(this.row);
  final EmptyRow row;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 12),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          AppIcon('sun', size: 48, color: c.muted),
          const SizedBox(height: 16),
          Text(row.title, textAlign: TextAlign.center, style: T.heading.copyWith(color: c.text)),
          if (row.text != null) ...[
            const SizedBox(height: 10),
            Text(row.text!, textAlign: TextAlign.center, style: T.body.copyWith(color: c.muted)),
          ],
        ],
      ),
    );
  }
}
