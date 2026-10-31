import 'package:flutter/material.dart';

import '../data/app_controller.dart';
import '../data/specs.dart';
import '../domain/directory.dart';
import '../domain/schedule.dart';
import '../domain/time_utils.dart';
import 'common.dart';
import 'derived.dart';
import 'group_picker.dart';
import 'icons.dart';
import 'not_found.dart';
import 'theme.dart';
import 'type_settings.dart';
import 'widgets.dart';

class SchedulePickerBody extends StatefulWidget {
  const SchedulePickerBody({super.key, required this.controller, this.onChosen, this.sheet = false});
  final AppController controller;
  final VoidCallback? onChosen;
  final bool sheet;

  @override
  State<SchedulePickerBody> createState() => _SchedulePickerBodyState();
}

class _SchedulePickerBodyState extends State<SchedulePickerBody> {
  late int _tab = widget.controller.store.prefs.value.activeTeacher.isNotEmpty ? 1 : 0;

  void _switchTab(int i) {
    final store = widget.controller.store;
    if (i == 0 && store.prefs.value.activeTeacher.isNotEmpty) store.setPrefs((p) => p.copyWith(activeTeacher: ''));
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedPill(options: const ['Группа', 'Преподаватели'], value: _tab, onChanged: _switchTab, height: 36),
          ),
          Expanded(
            child: _tab == 0
                ? GroupPickerBody(controller: widget.controller, onChosen: widget.onChosen, sheet: widget.sheet)
                : TeacherPickerBody(controller: widget.controller, onChosen: widget.onChosen, sheet: widget.sheet),
          ),
        ],
      );
}

class TeacherPickerBody extends StatefulWidget {
  const TeacherPickerBody({super.key, required this.controller, this.onChosen, this.sheet = false});
  final AppController controller;
  final VoidCallback? onChosen;
  final bool sheet;

  @override
  State<TeacherPickerBody> createState() => _TeacherPickerBodyState();
}

class _TeacherPickerBodyState extends State<TeacherPickerBody> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _choose(String name) {
    widget.controller.store.setPrefs((p) => p.copyWith(activeTeacher: name, savedTeachers: p.savedTeachers.contains(name) ? p.savedTeachers : [...p.savedTeachers, name]));
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
    widget.onChosen?.call();
  }

  void _toggleSaved(String name) {
    widget.controller.store.setPrefs((p) => p.copyWith(savedTeachers: p.savedTeachers.contains(name) ? [for (final n in p.savedTeachers) if (n != name) n] : [...p.savedTeachers, name]));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final controller = widget.controller;
    final bottom = widget.sheet ? MediaQuery.of(context).padding.bottom + 8 : 0.0;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _search,
            style: T.body.copyWith(color: c.text),
            cursorColor: c.link,
            decoration: InputDecoration(
              hintText: 'Фамилия преподавателя',
              hintStyle: T.body.copyWith(color: c.muted),
              prefixIcon: Padding(padding: const EdgeInsets.all(12), child: AppIcon('search', size: 20, color: c.muted)),
              filled: true,
              fillColor: c.surface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: Listenable.merge([_search, controller.store.prefs]),
            builder: (context, _) {
              final prefs = controller.store.prefs.value;
              final q = _search.text.trim().toLowerCase();
              Widget row(String name, String? detail) => _TeacherRow(
                    title: fullTeacherName(name, controller.names),
                    detail: detail,
                    selected: prefs.activeTeacher == name,
                    saved: prefs.savedTeachers.contains(name),
                    onTap: () => _choose(name),
                    onStar: () => _toggleSaved(name),
                  );
              if (q.isEmpty) {
                if (prefs.savedTeachers.isEmpty) {
                  return const Padding(padding: EdgeInsets.all(24), child: NothingFound(icon: 'teacher', hint: 'Введите фамилию преподавателя. Выбранные преподаватели сохраняются здесь.'));
                }
                return ListView(padding: EdgeInsets.only(bottom: bottom), children: [for (final n in prefs.savedTeachers) row(n, null)]);
              }
              return ResourceView<List<TeacherHit>>(
                resource: controller.hub.watch(teachersSpec()),
                builder: (context, all) {
                  final rows = [for (final t in all) if ('${t.name} ${fullTeacherName(t.name, controller.names)}'.toLowerCase().contains(q)) t].take(60).toList();
                  if (rows.isEmpty) {
                    return const Padding(padding: EdgeInsets.all(24), child: NothingFound(icon: 'teacher', hint: 'Такого преподавателя нет в опубликованных расписаниях. Попробуйте ввести только фамилию.'));
                  }
                  return ListView(
                    padding: EdgeInsets.only(bottom: bottom),
                    children: [for (final t in rows) row(t.name, [rankLabel(t.rank), '${t.lessons} ${plural(t.lessons, 'занятие', 'занятия', 'занятий')}'].where((e) => e.isNotEmpty).join(' · '))],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TeacherRow extends StatelessWidget {
  const _TeacherRow({required this.title, required this.detail, required this.selected, required this.saved, required this.onTap, required this.onStar});
  final String title;
  final String? detail;
  final bool selected;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onStar;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Tap(
      label: title,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.only(left: 20, top: 8, bottom: 8, right: 8),
        color: selected ? c.tint : Colors.transparent,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: T.subject.copyWith(color: selected ? c.link : c.text)),
                  if (detail != null && detail!.isNotEmpty) Text(detail!.cased, style: T.micro.copyWith(color: c.muted)),
                ],
              ),
            ),
            Tap(
              label: saved ? 'Убрать из сохранённых' : 'Сохранить преподавателя',
              onTap: onStar,
              child: SizedBox(width: 44, height: 44, child: Center(child: AppIcon('star', size: 20, color: saved ? c.link : c.muted))),
            ),
          ],
        ),
      ),
    );
  }
}
