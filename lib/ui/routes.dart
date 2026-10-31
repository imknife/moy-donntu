import 'package:flutter/material.dart';

import '../data/app_controller.dart';
import '../domain/brand.dart';
import '../domain/time_utils.dart';
import 'common.dart';
import 'deadlines_page.dart';
import 'load_analysis.dart';
import 'directory_pages.dart';
import 'changes_page.dart';
import 'groups_pages.dart';
import 'lesson_page.dart';
import 'motion.dart';
import 'note_editor.dart';
import 'notes_page.dart';
import 'profile.dart';
import 'schedule_screen.dart';
import 'scope.dart';
import 'notices_page.dart';
import 'settings_pages.dart';
import 'study_pages.dart';
import 'page_types.dart';
import 'stage3_pages.dart';

String _p(Map<String, String> params, String key) => params[key] ?? '';

final Map<String, PageBuilder> pageBuilders = {
  'group': (c, p) => ScheduleScreen(controller: c.app, previewGroup: _p(p, 'group')),
  'groups': (c, p) => const GroupsPage(),
  'changes': (c, p) => const ChangesPage(),
  'teachers': (c, p) => const TeachersPage(),
  'teacher': (c, p) => TeacherPage(name: _p(p, 'name')),
  'rooms': (c, p) => RoomsPage(building: p['building']),
  'room': (c, p) => RoomPage(room: _p(p, 'room'), date: p['date'], group: p['group']),
  'search': (c, p) => const SearchPage(),
  'lesson': (c, p) => LessonPage(date: parseYmd(_p(p, 'date')) ?? c.app.clock.value.today, lessonKey: _p(p, 'key'), group: _p(p, 'group'), subgroup: int.tryParse(_p(p, 'sub')) ?? 0),
  'notes': (c, p) => const NotesPage(),
  'deadlines': (c, p) => const DeadlinesPage(),
  'load': (c, p) => const LoadPage(),
  'note': (c, p) => NoteEditorPage(id: p['id']),
  'lesson-note': (c, p) => _lessonNote(c, p),
  'calendar': (c, p) => const CalendarExportPage(),
  'feedback': (c, p) => FeedbackPage(date: p['date'], group: p['group'], subject: p['subject'], num: int.tryParse(_p(p, 'num'))),
  'links': (c, p) => const LinksPage(),
  'about': (c, p) => const AboutPage(),
  'settings': (c, p) => const SettingsPage(),
  'appearance': (c, p) => const AppearancePage(),
  'notification-settings': (c, p) => const NotificationSettingsPage(),
  'widgets': (c, p) => const NotificationSettingsPage(),
  'notifications': (c, p) => const NotificationsPage(),
  'privacy': (c, p) => const DataPage(),
  'sync': (c, p) => const DataPage(),
  'start-screen': (c, p) => const StartScreenPage(),
  'edit-profile': (c, p) => const ProfileEditPage(),
  'avatar-edit': (c, p) => const ProfileEditPage(),
  'bells': (c, p) => const BellsPage(),
  'academic': (c, p) => const AcademicPage(),
  'session': (c, p) => const SessionPage(),
  ...stage3Pages,
};

Widget _lessonNote(BuildContext context, Map<String, String> p) {
  final app = context.app;
  final date = parseYmd(_p(p, 'date'));
  final key = _p(p, 'key');
  final own = app.store.selection.value.group;
  final group = p['group'] == null || p['group']!.isEmpty ? own : p['group']!;
  final model = group == own ? app.model.value : null;
  final item = date == null ? null : model?.findLesson(date, key);
  return NoteEditorPage(
    lessonKey: key.isEmpty ? null : key,
    lessonDate: date == null ? null : ymd(date),
    subject: item?.lesson.subject ?? p['subject'],
    kind: item?.lesson.kind ?? p['kind'],
  );
}

Route<dynamic>? generateAppRoute(RouteSettings settings, AppController controller) {
  final name = settings.name ?? '/';
  final uri = Uri.tryParse(name);
  if (uri == null) return null;
  final page = uri.path.replaceFirst(RegExp(r'^/'), '');
  if (page.isEmpty) return null;
  final builder = pageBuilders[page];
  return QuietRoute<void>(
    settings: settings,
    builder: (context) {
      if (builder == null) return const NotFoundPage();
      return ValueListenableBuilder<Features>(
        valueListenable: controller.features,
        builder: (context, features, _) => serviceVisible(page, features) ? builder(context, uri.queryParameters) : const NotFoundPage(),
      );
    },
  );
}

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Страница не найдена',
      children: [
        const EmptyBox(icon: 'search', title: 'Страница не найдена', text: 'Проверьте адрес страницы'),
        const VGap(12),
        PrimaryButton(label: 'Открыть расписание', onTap: () => context.openTab(1)),
      ],
    );
  }
}
