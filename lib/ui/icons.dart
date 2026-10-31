import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart' show LucideIcons;

import 'lucide.dart';

const Map<String, IconData> iconRegistry = {
  'home': Lucide.house,
  'schedule': Lucide.calendar,
  'services': Lucide.layoutGrid,
  'profile': Lucide.user,
  'search': Lucide.search,
  'bell': Lucide.bell,
  'lecture': Lucide.bookOpen,
  'practice': Lucide.pencil,
  'lab': Lucide.flaskConical,
  'room': Lucide.doorOpen,
  'pin': Lucide.mapPin,
  'changes': Lucide.arrowUpDown,
  'clock': Lucide.clock,
  'chevron': Lucide.chevronRight,
  'chevronLeft': Lucide.chevronLeft,
  'chevronDown': Lucide.chevronDown,
  'check': Lucide.check,
  'close': Lucide.x,
  'back': Lucide.arrowLeft,
  'coffee': Lucide.coffee,
  'teacher': Lucide.contactRound,
  'note': Lucide.notebookPen,
  'campus': Lucide.map,
  'gradebook': Lucide.bookCheck,
  'exam': Lucide.clipboardCheck,
  'academic': Lucide.calendarRange,
  'session': Lucide.hourglass,
  'walk': Lucide.footprints,
  'settings': Lucide.settings,
  'appearance': Lucide.palette,
  'privacy': Lucide.shieldCheck,
  'start': Lucide.smartphone,
  'knowledge': Lucide.libraryBig,
  'feedback': Lucide.messageSquareWarning,
  'sync': Lucide.refreshCw,
  'star': Lucide.star,
  'plus': Lucide.plus,
  'trash': Lucide.trash2,
  'checklist': Lucide.listChecks,
  'pencil': Lucide.pencil,
  'sun': Lucide.sun,
  'system': Lucide.monitor,
  'people': Lucide.users,
  'map': Lucide.map,
  'card': Lucide.idCard,
  'user': Lucide.userRound,
  'logout': Lucide.logOut,
  'file': Lucide.fileText,
  'swap': Lucide.arrowUpDown,
  'route': Lucide.route,
  'fit': Lucide.maximize,
  'minus': Lucide.minus,
  'eye': Lucide.eye,
  'calendarExport': Lucide.calendarPlus,
  'share': Lucide.share2,
  'chart': Lucide.chartColumn,
  'materials': Lucide.folderOpen,
  'link': Lucide.link,
  'font': Lucide.type,
  'info': Lucide.info,
  'filter': LucideIcons.slidersHorizontal,
  'deadline': LucideIcons.alarmClock,
};

const IconData _unknown = Lucide.circleHelp;

class AppIcon extends StatelessWidget {
  const AppIcon(this.name, {super.key, this.size = 22, required this.color, this.focused = false});
  final String name;
  final double size;
  final Color color;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    return Icon(iconRegistry[name] ?? _unknown, size: size, color: color);
  }
}
