import 'package:flutter/material.dart';

import '../data/app_controller.dart';
import '../domain/deadline.dart';
import '../domain/time_utils.dart';
import 'common.dart';
import 'deadline_sheet.dart';
import 'derived.dart';
import 'icons.dart';
import 'scope.dart';
import 'theme.dart';
import 'type_settings.dart';

class DeadlinesPage extends StatefulWidget {
  const DeadlinesPage({super.key});

  @override
  State<DeadlinesPage> createState() => _DeadlinesPageState();
}

class _DeadlinesPageState extends State<DeadlinesPage> {
  final Set<String> _picked = {};

  void _pick(String id) => setState(() {
        if (!_picked.add(id)) _picked.remove(id);
      });

  Future<void> _delete() async {
    final app = context.app;
    final ids = {..._picked};
    final count = ids.length;
    final ok = await confirm(context, title: 'Удалить $count ${plural(count, 'дедлайн', 'дедлайна', 'дедлайнов')}?');
    if (!ok || !mounted) return;
    app.store.removeDeadlines(ids);
    for (final id in ids) {
      await cancelDeadlineReminder(app, id);
    }
    if (mounted) setState(_picked.clear);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final app = context.app;
    final selecting = _picked.isNotEmpty;
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_picked.clear);
      },
      child: _page(context, c, app, selecting),
    );
  }

  Widget _page(BuildContext context, Pal c, AppController app, bool selecting) {
    return PageScaffold(
      title: selecting ? 'Выбрано: ${_picked.length}' : 'Дедлайны',
      actions: selecting
          ? [
              Tap(
                label: 'Выбрать все',
                onTap: () => setState(() => _picked.addAll([for (final d in app.store.deadlines.value) d.id])),
                child: SizedBox(height: 56, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Center(child: Text('Все', style: T.captionSemi.copyWith(color: c.link))))),
              ),
              Tap(
                label: 'Удалить выбранные',
                onTap: _delete,
                child: SizedBox(width: 52, height: 56, child: Center(child: AppIcon('trash', size: 22, color: c.danger))),
              ),
            ]
          : const [],
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      overlay: selecting
          ? null
          : Positioned(
              right: 16,
              bottom: 16,
              child: Tap(
                label: 'Новый дедлайн',
                onTap: () => showDeadlineSheet(context),
                child: Container(width: 56, height: 56, decoration: BoxDecoration(color: c.segmentOn, borderRadius: BorderRadius.circular(28)), alignment: Alignment.center, child: AppIcon('plus', size: 26, color: c.segmentOnText)),
              ),
            ),
      children: [
        Derived<int>(
          listenable: Listenable.merge([app.store.deadlines, app.clock]),
          read: () => Object.hash(app.store.deadlines.value, app.clock.value),
          builder: (context, _) {
            final list = app.store.deadlines.value;
            if (list.isEmpty) {
              return EmptyBox(icon: 'deadline', title: 'Дедлайнов нет', actionLabel: 'Добавить', onAction: () => showDeadlineSheet(context));
            }
            final today = app.clock.value.today;
            final minute = app.clock.value.minute;
            final groups = groupDeadlines(list, today, minute);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final bucket in DeadlineBucket.values)
                  if (groups[bucket]!.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                      child: Text(TypeSettings.caps(deadlineBucketTitles[bucket]!), style: T.sectionLabel.copyWith(color: bucket == DeadlineBucket.overdue ? c.danger : c.muted)),
                    ),
                    Container(
                      width: double.infinity,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18)),
                      child: Column(
                        children: [
                          for (var i = 0; i < groups[bucket]!.length; i++) ...[
                            if (i > 0) Divider(height: 1, thickness: 1, indent: 56, color: c.hairline),
                            DeadlineRow(
                              item: groups[bucket]![i],
                              today: today,
                              minute: minute,
                              selecting: selecting,
                              selected: _picked.contains(groups[bucket]![i].id),
                              onPick: () => _pick(groups[bucket]![i].id),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class DeadlineRow extends StatelessWidget {
  const DeadlineRow({super.key, required this.item, required this.today, required this.minute, this.selecting = false, this.selected = false, this.onPick});
  final Deadline item;
  final DateTime today;
  final int minute;
  final bool selecting;
  final bool selected;
  final VoidCallback? onPick;

  Future<void> _toggle(BuildContext context) async {
    final app = context.app;
    final next = item.copyWith(done: !item.done);
    app.store.saveDeadline(next);
    await syncDeadlineReminder(app, next);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final bucket = deadlineBucket(item, today, minute);
    final overdue = bucket == DeadlineBucket.overdue;
    final meta = [deadlineWhen(item, today, minute), if (item.subject != null && item.subject!.isNotEmpty) item.subject!].join(' · ');
    final filled = selecting ? selected : item.done;
    final ring = selecting ? (selected ? c.link : c.muted) : (item.done ? c.link : (overdue ? c.danger : c.muted));
    return GestureDetector(
      onLongPress: onPick,
      child: Tap(
        label: item.title,
        onTap: selecting ? onPick! : () => showDeadlineSheet(context, id: item.id),
        child: ColoredBox(
          color: selected ? c.tint : Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
              child: Row(
                children: [
                  Tap(
                    label: selecting ? 'Выбрать' : (item.done ? 'Вернуть в работу' : 'Отметить выполненным'),
                    onTap: selecting ? onPick! : () => _toggle(context),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled ? c.link : Colors.transparent,
                            border: Border.all(color: ring, width: 1.6),
                          ),
                          alignment: Alignment.center,
                          child: filled ? AppIcon('check', size: 14, color: c.onLink) : null,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.subject.copyWith(color: item.done ? c.muted : c.text, decoration: item.done ? TextDecoration.lineThrough : null, decorationColor: c.muted)),
                        if (meta.isNotEmpty) Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.micro.copyWith(color: overdue ? c.danger : c.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
