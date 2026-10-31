import 'campus_pages.dart';
import 'login_page.dart';
import 'materials_page.dart';
import 'page_types.dart';
import 'student_pages.dart';

final Map<String, PageBuilder> stage3Pages = {
  'login': (c, p) => const LoginPage(),
  'student-card': (c, p) => const StudentCardPage(),
  'gradebook': (c, p) => const GradebookPage(),
  'grade': (c, p) => GradeDetailPage(dis: p['dis'] ?? '', sem: int.tryParse(p['sem'] ?? '')),
  'cabinet': (c, p) => const CabinetPage(),
  'logout': (c, p) => const LogoutPage(),
  'campus': (c, p) => CampusPage(building: p['building'], from: p['from'], to: p['to']),
  'materials': (c, p) => MaterialsPage(lessonKey: p['key'], subject: p['subject']),
  'knowledge': (c, p) => const PlaceholderPage(title: 'Банк знаний', text: 'Раздел скрыт флагом из админки; в этой версии не переносится.'),
  'communities': (c, p) => const PlaceholderPage(title: 'Сообщества', text: 'Раздел скрыт флагом из админки; в этой версии не переносится.'),
  'polls': (c, p) => const PlaceholderPage(title: 'Опросы', text: 'Раздел скрыт флагом из админки; в этой версии не переносится.'),
};
