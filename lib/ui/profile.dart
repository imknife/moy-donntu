import 'package:flutter/material.dart';

import '../domain/cabinet_feed.dart';
import 'common.dart';
import 'derived.dart';
import 'icons.dart';
import 'lesson_page.dart';
import 'scope.dart';
import 'settings_group.dart';
import 'theme.dart';
import 'widgets.dart';
import 'type_settings.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.pal;
    return GroupedBackground(
      child: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([app.store.prefs, app.store.selection, app.session, app.auth.feed]),
          builder: (context, _) {
            final prefs = app.store.prefs.value;
            final sel = app.store.selection.value;
            final session = app.session.value;
            final feed = app.auth.feed.value.data;
            final name = prefs.displayName;
            final title = name.isNotEmpty ? name : (session != null ? 'Студент' : 'Гость');
            final subtitle = '${session != null ? 'Студент' : 'Без входа'}${sel.group.isNotEmpty ? ' · ${sel.group}' : ''}';
            return ListView(
              padding: const EdgeInsets.fromLTRB(groupedSide, 0, groupedSide, 16),
              children: [
                const ScreenTitle('Профиль', horizontal: 0),
                SettingsGroup(top: 4, children: [
                  Tap(
                    onTap: () => context.open('edit-profile'),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(color: c.tint, borderRadius: BorderRadius.circular(28)),
                          alignment: Alignment.center,
                          child: name.isNotEmpty ? Text(initials(name), style: T.heading.copyWith(color: c.link)) : AppIcon('profile', size: 28, color: c.link, focused: true),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(title, style: T.heading.copyWith(color: c.text)),
                            Text(subtitle, style: T.caption.copyWith(color: c.muted)),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        AppIcon('chevron', size: 18, color: c.muted),
                      ]),
                    ),
                  ),
                ]),
                if (session == null) ...[const VGap(groupGap), PrimaryButton(label: 'Войти', onTap: () => context.open('login'))],
                SettingsGroup(title: 'Учёба', top: 16, children: [
                  SettingsRow(icon: 'schedule', title: 'Мои расписания', detail: sel.group.isEmpty ? 'Выбрать группу' : '${sel.group} · ${sel.subgroup > 0 ? '${sel.subgroup} подгруппа' : 'вся группа'}', onTap: () => context.open('groups')),
                  if (session != null) SettingsRow(icon: 'bell', title: 'Лента кабинета', detail: feed != null ? feedSummary(feed.absences, feed.unread) : 'Пропуски, оценки, приказы', onTap: () => context.open('cabinet')),
                ]),
                SettingsGroup(title: 'Настройки', top: 16, children: [
                  SettingsRow(icon: 'bell', title: 'Напоминания', onTap: () => context.open('notification-settings')),
                  SettingsRow(icon: 'appearance', title: 'Оформление', onTap: () => context.open('appearance')),
                  SettingsRow(icon: 'settings', title: 'Расписание', onTap: () => context.open('settings')),
                  SettingsRow(icon: 'privacy', title: 'Данные', onTap: () => context.open('privacy')),
                ]),
                SettingsGroup(children: [
                  SettingsRow(icon: 'info', title: 'О приложении', onTap: () => context.open('about')),
                  if (session != null) SettingsRow(icon: 'logout', title: 'Выйти из аккаунта', onTap: () => context.open('logout')),
                ]),
              ],
            );
          },
        ),
      ),
    );
  }
}

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  late final TextEditingController _name = TextEditingController(text: context.app.store.prefs.value.displayName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final saved = context.app.store.prefs.value.displayName;
    return GroupedPage(
      title: 'Профиль',
      children: [
        TextField(
          controller: _name,
          onChanged: (_) => setState(() {}),
          style: T.body.copyWith(color: c.text),
          cursorColor: c.link,
          decoration: InputDecoration(
            hintText: 'Отображаемое имя',
            hintStyle: T.body.copyWith(color: c.muted),
            filled: true,
            fillColor: c.island,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const VGap(8),
        Text('Имя видно только на этом телефоне.'.cased, style: T.caption.copyWith(color: c.muted)),
        const VGap(12),
        PrimaryButton(
          label: 'Сохранить',
          enabled: _name.text.trim() != saved,
          onTap: () {
            context.app.store.setPrefs((p) => p.copyWith(displayName: _name.text.trim()));
            showToast(context, 'Профиль сохранён');
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
