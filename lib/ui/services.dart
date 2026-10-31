import 'package:flutter/material.dart';

import '../domain/brand.dart';
import '../domain/time_utils.dart';
import 'common.dart';
import 'derived.dart';
import 'icons.dart';
import 'scope.dart';
import 'settings_group.dart';
import 'theme.dart';
import 'widgets.dart';
import 'type_settings.dart';

class Service {
  const Service(this.route, this.icon, this.name, this.detail, this.section, {this.isNew = false});
  final String route;
  final String icon;
  final String name;
  final String detail;
  final String section;
  final bool isNew;
}

const services = <Service>[
  Service('gradebook', 'gradebook', 'Зачётная книжка', 'Оценки по семестрам', 'Учёба'),
  Service('student-card', 'card', 'Студенческий билет', 'Данные студента', 'Учёба'),
  Service('knowledge', 'knowledge', 'Банк знаний', 'Конспекты, билеты и шпоры от студентов', 'Учёба'),
  Service('deadlines', 'deadline', 'Дедлайны', 'Сроки сдачи и напоминания', 'Учёба', isNew: true),
  Service('notes', 'note', 'Заметки', 'Записи к парам и свои', 'Учёба'),
  Service('load', 'chart', 'Нагрузка недели', 'Пары и часы по дням', 'Учёба'),
  Service('rooms', 'room', 'Аудитории', 'Свободные сейчас и занятость по дням', 'Кампус', isNew: true),
  Service('teachers', 'teacher', 'Преподаватели', 'Где и когда ведёт пары', 'Кампус'),
  Service('campus', 'campus', 'Карта кампуса', 'Корпуса и как их найти', 'Кампус'),
  Service('communities', 'people', 'Сообщества', 'Обсуждения групп и кафедр', 'Вместе'),
  Service('polls', 'checklist', 'Опросы', 'Голосования в группе', 'Вместе'),
  Service('links', 'link', 'Полезные ссылки', 'Сайт вуза, ACE, библиотека', 'Полезное'),
];

const serviceSections = ['Учёба', 'Кампус', 'Вместе', 'Полезное'];

class ServicesTab extends StatefulWidget {
  const ServicesTab({super.key});

  @override
  State<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<ServicesTab> {
  bool _editing = false;

  void _toggle(Service s) {
    final store = context.app.store;
    final current = store.prefs.value.quickServices;
    final has = current.contains(s.route);
    store.setPrefs((p) => p.copyWith(quickServices: has ? [for (final r in current) if (r != s.route) r] : [...current, s.route]));
    showToast(context, has ? '«${s.name}» убран из избранного' : '«${s.name}» в избранном');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final app = context.app;
    return GroupedBackground(
      child: SafeArea(
        bottom: false,
        child: Derived<(Features, List<String>, int)>(
          listenable: Listenable.merge([app.features, app.store.prefs, app.store.notes]),
          read: () => (app.features.value, app.store.prefs.value.quickServices, app.store.notes.value.length),
          builder: (context, state) {
            final features = state.$1;
            final favourites = state.$2;
            final noteCount = state.$3;
            final visible = [for (final s in services) if (serviceVisible(s.route, features)) s];
            final picked = [for (final s in visible) if (favourites.contains(s.route)) s];
            Widget row(Service s) {
              final detail = s.route == 'notes' && noteCount > 0 ? '$noteCount ${plural(noteCount, 'заметка', 'заметки', 'заметок')} на телефоне' : s.detail;
              return _ServiceRow(
                service: s,
                detail: detail,
                onTap: () => _editing ? _toggle(s) : context.open(s.route),
                trailing: _editing ? AppIcon('star', size: 20, color: favourites.contains(s.route) ? c.link : c.axis) : null,
              );
            }

            final sections = [
              for (final section in serviceSections)
                (section, [for (final s in visible) if (s.section == section && (_editing || !favourites.contains(s.route))) s]),
            ];
            return ListView(
              padding: const EdgeInsets.fromLTRB(groupedSide, 0, groupedSide, 16),
              children: [
                const ScreenTitle('Сервисы', horizontal: 0),
                const SizedBox(height: 4),
                SearchEntry(onTap: () => context.open('search')),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [
                    const Expanded(child: Padding(padding: EdgeInsets.only(left: 16, top: 8, bottom: 8), child: _GroupTitle('Избранное'))),
                    Tap(
                      onTap: () => setState(() => _editing = !_editing),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 40),
                        child: Padding(padding: const EdgeInsets.only(left: 16, right: 16), child: Align(alignment: Alignment.centerRight, widthFactor: 1, child: Text(TypeSettings.caps(_editing ? 'Готово' : 'Изменить'), style: T.sectionLabel.copyWith(color: c.link)))),
                      ),
                    ),
                  ]),
                ),
                if (_editing)
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Нажмите на звёздочку, чтобы добавить сервис в избранное.'.cased, style: T.caption.copyWith(color: c.muted)))
                else if (picked.isNotEmpty)
                  SettingsGroup(top: 0, children: [for (final s in picked) row(s)])
                else
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Нажмите «Изменить», чтобы собрать избранные сервисы.'.cased, style: T.caption.copyWith(color: c.muted))),
                for (final section in sections)
                  if (section.$2.isNotEmpty) SettingsGroup(title: section.$1, top: 16, children: [for (final s in section.$2) row(s)]),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.service, required this.detail, required this.onTap, this.trailing});
  final Service service;
  final String detail;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Tap(
      label: service.name,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: c.background, borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: AppIcon(service.icon, size: 18, color: c.text),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(service.name.cased, style: T.subject.copyWith(color: c.text)),
                        if (service.isNew)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: c.tint, borderRadius: BorderRadius.circular(8)),
                            child: Text('Новое'.cased, style: T.microSemi.copyWith(color: c.link)),
                          ),
                      ],
                    ),
                    Text(detail.cased, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.micro.copyWith(color: c.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ?? AppIcon('chevron', size: 16, color: c.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(TypeSettings.caps(text), style: T.sectionLabel.copyWith(color: context.pal.muted));
}

class SearchEntry extends StatelessWidget {
  const SearchEntry({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Tap(
      label: 'Поиск преподавателей, аудиторий и групп',
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: c.island, borderRadius: BorderRadius.circular(groupRadius)),
        child: Row(children: [
          AppIcon('search', size: 20, color: c.muted),
          const SizedBox(width: 10),
          Expanded(child: Text('Найти сервис или человека'.cased, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.bodyLink.copyWith(fontWeight: FontWeight.w400, color: c.muted))),
        ]),
      ),
    );
  }
}
