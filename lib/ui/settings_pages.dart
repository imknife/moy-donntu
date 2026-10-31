import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/native_bridge.dart';
import '../data/store.dart';
import '../domain/time_utils.dart';
import 'common.dart';
import 'icons.dart';
import 'scope.dart';
import 'settings_group.dart';
import 'theme.dart';
import 'widgets.dart';
import 'type_settings.dart';

const appVersion = '1.0.0';

const _startNames = {'overview': 'Обзор', 'schedule': 'Расписание', 'services': 'Сервисы', 'profile': 'Профиль'};

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.app.store;
    return GroupedPage(
      title: 'Расписание',
      children: [
        ValueListenableBuilder2(
          first: store.selection,
          second: store.prefs,
          builder: (context, sel, prefs) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SettingsGroup(children: [
              SettingsRow(icon: 'schedule', title: 'Группа и подгруппа', detail: '${sel.group.isEmpty ? 'Не выбрана' : sel.group}${sel.subgroup > 0 ? ' · ${sel.subgroup} подгруппа' : ''}', onTap: () => context.open('groups')),
              SettingsRow(icon: 'start', title: 'Экран при запуске', detail: _startNames[prefs.startScreen] ?? 'Расписание', onTap: () => context.open('start-screen')),
            ]),
            SettingsGroup(title: 'Что показывать', top: 16, children: [
              SettingsToggle(title: 'Скрывать прошедшие пары', value: prefs.hidePast, onChanged: (v) => store.setPrefs((p) => p.copyWith(hidePast: v))),
              SettingsToggle(title: 'Показывать отменённые пары', value: prefs.showCancelled, onChanged: (v) => store.setPrefs((p) => p.copyWith(showCancelled: v))),
            ]),
          ]),
        ),
      ],
    );
  }
}

class ValueListenableBuilder2<A, B> extends StatelessWidget {
  const ValueListenableBuilder2({super.key, required this.first, required this.second, required this.builder});
  final ValueListenable<A> first;
  final ValueListenable<B> second;
  final Widget Function(BuildContext context, A a, B b) builder;

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Listenable.merge([first, second]), builder: (context, _) => builder(context, first.value, second.value));
}

class AppearancePage extends StatelessWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.app.store;
    return GroupedPage(
      title: 'Оформление',
      children: [
        ValueListenableBuilder<Prefs>(
          valueListenable: store.prefs,
          builder: (context, prefs, _) {
            const order = [ThemeChoice.light, ThemeChoice.dark, ThemeChoice.system];
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SettingsGroup(title: 'Тема', children: [
                Padding(padding: const EdgeInsets.all(8), child: SegmentedPill(options: const ['Светлая', 'Тёмная', 'Системная'], value: order.indexOf(prefs.theme), onChanged: (i) => store.setPrefs((p) => p.copyWith(theme: order[i])), height: 36)),
              ]),
              SettingsGroup(title: 'Текст', top: 16, children: [
                Padding(padding: const EdgeInsets.all(8), child: SegmentedPill(options: const ['Обычный', 'Крупный'], value: prefs.largeText ? 1 : 0, onChanged: (i) => store.setPrefs((p) => p.copyWith(largeText: i == 1)), height: 36)),
              ]),
            ]);
          },
        ),
      ],
    );
  }
}

class StartScreenPage extends StatelessWidget {
  const StartScreenPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.app.store;
    final c = context.pal;
    return GroupedPage(
      title: 'Экран при запуске',
      children: [
        ValueListenableBuilder<Prefs>(
          valueListenable: store.prefs,
          builder: (context, prefs, _) => SettingsGroup(children: [
            for (final e in _startNames.entries)
              SettingsRow(
                icon: switch (e.key) { 'overview' => 'home', 'schedule' => 'schedule', 'services' => 'services', _ => 'profile' },
                title: e.value,
                trailing: prefs.startScreen == e.key ? AppIcon('check', size: 20, color: c.link) : const SizedBox(width: 0),
                onTap: () => store.setPrefs((p) => p.copyWith(startScreen: e.key)),
              ),
          ]),
        ),
      ],
    );
  }
}

class DataPage extends StatefulWidget {
  const DataPage({super.key});

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  String _status = '';

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.pal;
    return GroupedPage(
      title: 'Данные',
      children: [
        ValueListenableBuilder<Prefs>(
          valueListenable: app.store.prefs,
          builder: (context, prefs, _) => SettingsGroup(children: [SettingsToggle(title: 'Обновлять автоматически', value: prefs.autoSync, onChanged: (v) => app.store.setPrefs((p) => p.copyWith(autoSync: v)))]),
        ),
        const VGap(groupGap),
        PrimaryButton(
          label: 'Обновить сейчас',
          onTap: () async {
            setState(() => _status = 'Обновляем…');
            await app.refreshAll();
            if (mounted) setState(() => _status = app.hub.api.enabled ? 'Данные обновлены' : 'Сервер не настроен: показаны встроенные данные');
          },
        ),
        SettingsGroup(children: [
          SettingsRow(
            icon: 'privacy',
            title: 'Очистить временные данные',
            onTap: () async {
              await app.hub.records.removePrefix('public:');
              if (mounted) setState(() => _status = 'Временные данные очищены');
            },
          ),
        ]),
        if (_status.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_status, style: T.caption.copyWith(color: c.muted))),
      ],
    );
  }
}

const _reminderMinutes = [5, 10, 15, 30, 60];

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> with WidgetsBindingObserver {
  NativeStatus _status = const NativeStatus();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final status = await context.app.native.status();
    if (mounted) setState(() => _status = status);
  }

  Future<void> _permission({bool resume = false}) async {
    final app = context.app;
    if (resume) await app.native.resume();
    await app.native.requestNotifications();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    if (!app.native.available) {
      return const GroupedPage(
        title: 'Напоминания',
        children: [EmptyBox(icon: 'bell', title: 'Только на Android', text: 'Напоминания, пара на экране блокировки и виджет работают на телефонах с Android.')],
      );
    }
    final s = _status;
    Widget problem(String title, String hint, String target, {VoidCallback? after}) => SettingsRow(
          icon: 'settings',
          title: title,
          detail: hint,
          onTap: () async {
            final opened = await app.native.openSettings(target);
            if (!opened && context.mounted) showToast(context, 'Откройте настройки приложения вручную');
            after?.call();
          },
        );
    return GroupedPage(
      title: 'Напоминания',
      children: [
        ValueListenableBuilder<Prefs>(
          valueListenable: app.store.prefs,
          builder: (context, prefs, _) {
            final problems = <Widget>[
              if (prefs.lockscreen || prefs.persistent || prefs.reminders || prefs.changeAlerts) ...[
                if (!s.notifications) problem('Уведомления запрещены', 'Разрешить', 'notifications'),
              ],
              if (prefs.lockscreen || prefs.persistent || prefs.reminders) ...[
                if (!s.exactAlarms) problem('Нет точных будильников', 'Разрешить', 'exactAlarms'),
              ],
              if (prefs.lockscreen || prefs.persistent) ...[
                if (s.vivo && !prefs.autostartDone) problem('Автозапуск', 'Разрешить работу в фоне', 'autostart', after: () => app.store.setPrefs((p) => p.copyWith(autostartDone: true))),
              ],
              if (prefs.persistent && !s.promoted) problem('Нет закрепления на экране', 'Разрешить', 'promoted'),
            ];
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SettingsGroup(children: [
                SettingsToggle(
                  title: 'Напоминание перед парой',
                  value: prefs.reminders,
                  onChanged: (v) {
                    app.store.setPrefs((p) => p.copyWith(reminders: v));
                    if (v) _permission();
                  },
                ),
                if (prefs.reminders)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final m in _reminderMinutes) PillButton(label: '$m мин', selected: prefs.notificationMinutes == m, onTap: () => app.store.setPrefs((p) => p.copyWith(notificationMinutes: m))),
                    ]),
                  ),
                SettingsToggle(
                  title: 'Пара на экране блокировки',
                  value: prefs.lockscreen,
                  onChanged: (v) {
                    app.store.setPrefs((p) => p.copyWith(lockscreen: v));
                    if (v) _permission(resume: true);
                  },
                ),
                SettingsToggle(
                  title: 'Постоянное уведомление',
                  value: prefs.persistent,
                  onChanged: (v) {
                    app.store.setPrefs((p) => p.copyWith(persistent: v));
                    if (v) _permission(resume: true);
                  },
                ),
                SettingsToggle(
                  title: 'Изменения в расписании',
                  value: prefs.changeAlerts,
                  onChanged: (v) {
                    app.store.setPrefs((p) => p.copyWith(changeAlerts: v));
                    if (v) _permission();
                  },
                ),
              ]),
              if (problems.isNotEmpty || (s.stoppedToday && (prefs.lockscreen || prefs.persistent))) ...[
                const VGap(groupGap),
                SettingsGroup(children: [
                  if (s.stoppedToday && (prefs.lockscreen || prefs.persistent))
                    SettingsRow(
                      icon: 'sync',
                      title: 'Остановлено на сегодня',
                      detail: 'Включить снова',
                      onTap: () async {
                        await app.native.resume();
                        await _load();
                      },
                    ),
                  ...problems,
                ]),
              ],
            ]);
          },
        ),
      ],
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<String> _seedLine() async {
    try {
      final meta = jsonDecode(await rootBundle.loadString('assets/seed/seed-meta.json')) as Map<String, dynamic>;
      final d = toMsk(DateTime.parse(meta['dataUpdatedAt'] as String));
      String p(int n) => n.toString().padLeft(2, '0');
      final n = meta['groups'] as int;
      return 'Встроенное расписание от ${p(d.day)}.${p(d.month)} в ${d.hour}:${p(d.minute)} · $n ${plural(n, 'группа', 'группы', 'групп')}';
    } catch (_) {
      return '';
    }
  }

  String _loadedLine(BuildContext context) {
    final app = context.app;
    final pkg = app.model.value?.pkg;
    final t = pkg == null ? null : DateTime.tryParse(pkg.updatedAt);
    if (t == null) return '';
    final d = toMsk(t);
    String p(int n) => n.toString().padLeft(2, '0');
    final n = app.groups.value.length;
    return 'Расписание от ${d.day} ${monthsGenitive[d.month - 1]}, ${p(d.hour)}:${p(d.minute)} · $n ${plural(n, 'группа', 'группы', 'групп')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final brand = context.app.brand.value;
    return GroupedPage(
      title: 'О приложении',
      children: [
        Row(children: [
          const IconTile('schedule', size: 48),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(brand.title, style: T.display.copyWith(color: c.text, fontSize: 24, height: 30 / 24)), Text(brand.disclaimer, style: T.caption.copyWith(color: c.muted))])),
        ]),
        const VGap(12),
        ListenableBuilder(
          listenable: Listenable.merge([context.app.model, context.app.groups]),
          builder: (context, _) {
            final loaded = _loadedLine(context);
            if (loaded.isNotEmpty) return Text(loaded, style: T.caption.copyWith(color: c.muted));
            return FutureBuilder<String>(future: _seedLine(), builder: (context, snap) => Text(snap.data ?? '', style: T.caption.copyWith(color: c.muted)));
          },
        ),
        const VGap(4),
        Text('Версия $appVersion · Flutter'.cased, style: T.caption.copyWith(color: c.muted)),
      ],
    );
  }
}

class LinksPage extends StatelessWidget {
  const LinksPage({super.key});

  static const _links = [
    ('Сайт ДонНТУ', 'donntu.ru', 'https://donntu.ru/', 'link'),
    ('Личный кабинет ACE', 'ace.donntu.ru', 'https://ace.donntu.ru', 'card'),
    ('Дистанционное обучение', 'donntu.ru/distance-learning', 'https://donntu.ru/distance-learning', 'lecture'),
    ('Научно-техническая библиотека', 'donntu.ru/library', 'https://donntu.ru/library', 'knowledge'),
  ];

  @override
  Widget build(BuildContext context) {
    return GroupedPage(
      title: 'Полезные ссылки',
      children: [
        SettingsGroup(children: [for (final l in _links) SettingsRow(icon: l.$4, title: l.$1, detail: l.$2, trailing: const SizedBox(width: 0), onTap: () => launchUrl(Uri.parse(l.$3), mode: LaunchMode.externalApplication))]),
      ],
    );
  }
}

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key, this.date, this.group, this.subject, this.num});
  final String? date;
  final String? group;
  final String? subject;
  final int? num;

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final TextEditingController _text = TextEditingController();
  String _status = '';
  Object? _error;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final app = context.app;
    final group = widget.group ?? app.store.selection.value.group;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await app.hub.api.send('/reports', body: {
        'groupCode': group,
        if (widget.date != null) 'date': widget.date,
        if (widget.num != null && widget.num != 0) 'num': widget.num,
        if (widget.subject != null) 'subject': widget.subject,
        'text': _text.text.trim(),
      });
      if (mounted) {
        setState(() {
          _status = 'Сообщение принято сервером';
          _text.clear();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final app = context.app;
    final group = widget.group ?? app.store.selection.value.group;
    return GroupedPage(
      title: 'Сообщить об ошибке',
      children: [
        Text('$group · ${widget.subject ?? 'Расписание'}', style: T.body.copyWith(color: c.muted)),
        const VGap(8),
        TextField(
          controller: _text,
          minLines: 4,
          maxLines: null,
          onChanged: (_) => setState(() {}),
          style: T.body.copyWith(color: c.text),
          cursorColor: c.link,
          decoration: InputDecoration(
            hintText: 'Опишите ошибку или изменение',
            hintStyle: T.body.copyWith(color: c.muted),
            filled: true,
            fillColor: c.island,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const VGap(8),
        PrimaryButton(label: 'Отправить диспетчеру', enabled: _text.text.trim().isNotEmpty && group.isNotEmpty && !_busy && app.hub.api.enabled, onTap: _send),
        if (!app.hub.api.enabled) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Отправка работает, когда настроен адрес сервера.'.cased, style: T.caption.copyWith(color: c.muted))),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: ErrorBox(error: _error!)),
        if (_status.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_status, style: T.captionSemi.copyWith(color: c.link))),
      ],
    );
  }
}
