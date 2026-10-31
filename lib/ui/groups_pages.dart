import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/store.dart';
import 'common.dart';
import 'derived.dart';
import 'group_picker.dart';
import 'icons.dart';
import 'not_found.dart';
import 'scope.dart';
import 'theme.dart';
import 'widgets.dart';
import 'type_settings.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _choose(String code) async {
    final app = context.app;
    try {
      await app.chooseGroup(code);
    } catch (_) {
      return;
    }
    if (mounted) showToast(context, 'Группа $code выбрана');
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.pal;
    return PageScaffold(
      title: 'Мои расписания',
      children: [
        ValueListenableBuilder<Selection>(
          valueListenable: app.store.selection,
          builder: (context, sel, _) => SurfaceCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Моя группа · ${sel.group.isEmpty ? 'не выбрана' : sel.group}'.cased, style: T.subject.copyWith(color: c.text)),
              const SizedBox(height: 8),
              if (sel.group.isNotEmpty)
                SegmentedPill(options: const ['Вся группа', '1 подгруппа', '2 подгруппа'], value: sel.subgroup, onChanged: app.chooseSubgroup, height: 34)
              else
                Text('Нажмите на свою группу в списке — подгруппу можно уточнить потом.'.cased, style: T.caption.copyWith(color: c.muted)),
            ]),
          ),
        ),
        ValueListenableBuilder<Selection>(
          valueListenable: app.store.selection,
          builder: (context, sel, _) => sel.group.isEmpty
              ? const SizedBox.shrink()
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SectionLabel('Экспорт'),
                  RowsCard(children: [
                    MenuRow(icon: 'calendarExport', title: 'Экспорт в календарь (.ics)', detail: 'Добавить расписание в календарь телефона', onTap: () => context.open('calendar')),
                  ]),
                  const SectionLabel('Сменить группу'),
                ]),
        ),
        SearchBox(controller: _search, hint: 'Найти группу'),
        const VGap(8),
        ValueListenableBuilder(
          valueListenable: app.groups,
          builder: (context, groups, _) => ListenableBuilder(
            listenable: Listenable.merge([_search, app.store.selection]),
            builder: (context, _) {
              final list = filterGroups(groups, _search.text);
              if (list.isEmpty) return const NothingFound(hint: 'Такой группы нет. Попробуйте другое название или факультет.');
              final current = app.store.selection.value.group;
              return SurfaceCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: [
                  for (final g in list)
                    Row(children: [
                      Expanded(
                        child: MenuRow(
                          icon: 'schedule',
                          title: g.code,
                          detail: '${g.faculty}${g.course != null ? ' · ${g.course} курс' : ''}',
                          trailing: g.code == current ? AppIcon('check', size: 20, color: c.link) : const SizedBox(width: 0),
                          onTap: () => _choose(g.code),
                        ),
                      ),
                      Tap(
                        label: 'Посмотреть расписание ${g.code}',
                        onTap: () => context.open('group', {'group': g.code}),
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(12)),
                          child: Text('Посмотреть'.cased, style: T.caption.copyWith(color: c.text)),
                        ),
                      ),
                    ]),
                ]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class CalendarExportPage extends StatefulWidget {
  const CalendarExportPage({super.key});

  @override
  State<CalendarExportPage> createState() => _CalendarExportPageState();
}

class _CalendarExportPageState extends State<CalendarExportPage> {
  bool _busy = false;

  Future<void> _add(String path) async {
    final app = context.app;
    setState(() => _busy = true);
    try {
      final text = await app.hub.api.send(path);
      final dir = Directory('${(await getTemporaryDirectory()).path}${Platform.pathSeparator}share_plus');
      await dir.create(recursive: true);
      final file = File('${dir.path}${Platform.pathSeparator}raspisanie.ics');
      await file.writeAsString(text);
      final opened = await app.native.openCalendarFile(file.path);
      if (!opened) await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'text/calendar', name: 'raspisanie.ics')]));
    } catch (_) {
      if (mounted) showToast(context, 'Не удалось получить расписание. Проверьте соединение');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.pal;
    final sel = app.store.selection.value;
    final base = app.hub.api.baseUrl;
    final path = sel.group.isEmpty ? null : '/groups/${Uri.encodeComponent(sel.group)}/calendar.ics?sub=${sel.subgroup}';
    return PageScaffold(
      title: 'Экспорт расписания',
      children: [
        SurfaceCard(child: Text(sel.group.isEmpty ? 'Группа не выбрана' : sel.group, style: T.heading.copyWith(color: c.text))),
        const VGap(12),
        if (path == null || base == null)
          const EmptyBox(icon: 'calendarExport', title: 'Экспорт недоступен', text: 'Он появляется, когда выбрана группа и настроен адрес сервера.')
        else ...[
          PrimaryButton(label: _busy ? 'Загружаю…' : 'Добавить в календарь', enabled: !_busy, onTap: () => _add(path)),
          const VGap(8),
          PrimaryButton(
            label: 'Скопировать ссылку подписки',
            secondary: true,
            onTap: () {
              Clipboard.setData(ClipboardData(text: '$base$path'));
              showToast(context, 'Ссылка скопирована');
            },
          ),
        ],
      ],
    );
  }
}
