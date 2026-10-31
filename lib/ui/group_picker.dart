import 'package:flutter/material.dart';

import '../data/app_controller.dart';
import '../data/loader.dart';
import 'derived.dart';
import 'icons.dart';
import 'sheet.dart';
import 'not_found.dart';
import 'schedule_picker.dart';
import 'theme.dart';
import 'widgets.dart';
import 'type_settings.dart';

List<GroupInfo> filterGroups(List<GroupInfo> groups, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return groups;
  return groups.where((g) => '${g.code} ${g.faculty}'.toLowerCase().contains(needle)).toList();
}

class GroupPickerPage extends StatelessWidget {
  const GroupPickerPage({super.key, required this.controller, this.onChosen});
  final AppController controller;
  final VoidCallback? onChosen;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            const BackBar(title: 'Расписание'),
            Expanded(child: SchedulePickerBody(controller: controller, onChosen: onChosen)),
          ],
        ),
      ),
    );
  }
}

Future<void> showGroupSheet(BuildContext context, AppController controller) =>
    showAppSheet<void>(context, title: 'Расписание', tall: true, scrollable: false, builder: (_) => SchedulePickerBody(controller: controller, sheet: true));

class GroupPickerBody extends StatefulWidget {
  const GroupPickerBody({super.key, required this.controller, this.onChosen, this.sheet = false});
  final AppController controller;
  final VoidCallback? onChosen;
  final bool sheet;

  @override
  State<GroupPickerBody> createState() => _GroupPickerBodyState();
}

class _GroupPickerBodyState extends State<GroupPickerBody> {
  final TextEditingController _search = TextEditingController();
  late int _subgroup = widget.controller.store.selection.value.subgroup;
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _choose(String code) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.controller.chooseGroup(code, subgroup: _subgroup);
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
    widget.onChosen?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final current = widget.controller.store.selection.value.group;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SegmentedPill(
            options: const ['Вся группа', '1 подгруппа', '2 подгруппа'],
            value: _subgroup,
            onChanged: (i) {
              setState(() => _subgroup = i);
              widget.controller.chooseSubgroup(i);
            },
            height: 36,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _search,
            style: T.body.copyWith(color: c.text),
            cursorColor: c.link,
            decoration: InputDecoration(
              hintText: 'Группа, факультет',
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
            listenable: _search,
            builder: (context, _) {
              final groups = filterGroups(widget.controller.groups.value, _search.text);
              if (groups.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: NothingFound(hint: 'Такой группы нет. Попробуйте другое название или факультет.'),
                );
              }
              return ListView.builder(
                padding: EdgeInsets.only(bottom: widget.sheet ? MediaQuery.of(context).padding.bottom + 8 : 0),
                itemCount: groups.length,
                itemBuilder: (context, i) {
                  final g = groups[i];
                  final selected = g.code == current;
                  return Tap(
                    label: g.code,
                    onTap: () => _choose(g.code),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 60),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      color: selected ? c.tint : Colors.transparent,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(g.code, style: T.subject.copyWith(color: selected ? c.link : c.text)),
                                Text('${g.faculty}${g.course != null ? ' · ${g.course} курс' : ''}'.cased, style: T.micro.copyWith(color: c.muted)),
                              ],
                            ),
                          ),
                          if (selected) AppIcon('check', size: 20, color: c.link),
                        ],
                      ),
                    ),
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
