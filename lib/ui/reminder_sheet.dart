import 'package:flutter/material.dart';

import '../data/app_controller.dart';
import '../domain/reminder.dart';
import '../domain/schedule.dart';
import '../domain/time_utils.dart';
import 'common.dart';
import 'scope.dart';
import 'sheet.dart';
import 'theme.dart';

const reminderChoices = [5, 10, 15, 30, 60];

Future<void> showReminderSheet(BuildContext context, {required DateTime date, required DayLesson lesson}) {
  final controller = context.app;
  final bell = lesson.bell;
  return showAppSheet<void>(
    context,
    title: 'Напомнить',
    subtitle: '${lesson.lesson.subject} · ${shortTime(bell.start)}–${shortTime(bell.end)}',
    builder: (_) => ReminderSheetBody(controller: controller, date: date, lesson: lesson),
  );
}

class ReminderSheetBody extends StatefulWidget {
  const ReminderSheetBody({super.key, required this.controller, required this.date, required this.lesson});
  final AppController controller;
  final DateTime date;
  final DayLesson lesson;

  @override
  State<ReminderSheetBody> createState() => _ReminderSheetBodyState();
}

class _ReminderSheetBodyState extends State<ReminderSheetBody> {
  late int _minutes = widget.controller.store.prefs.value.notificationMinutes;
  final TextEditingController _custom = TextEditingController();
  bool _ownTime = false;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  String get _value => _ownTime ? _custom.text.trim() : '$_minutes';

  Future<void> _done() async {
    final model = reminderModel(ymd(widget.date), widget.lesson.bell.start, _value, DateTime.now().millisecondsSinceEpoch);
    if (!model.valid) {
      setState(() => _error = model.error);
      return;
    }
    setState(() => _busy = true);
    final native = widget.controller.native;
    await native.requestNotifications();
    final id = Object.hash(ymd(widget.date), widget.lesson.key) & 0xFFFF;
    final it = widget.lesson;
    final placed = await native.scheduleManual(id, model.triggerMillis, it.lesson.subject, 'Через ${model.minutes} мин · ${kindLabel[it.lesson.kind] ?? ''} · ${roomsLabel(it.lesson)}');
    if (!mounted) return;
    showToast(context, placed ? 'Напоминание поставлено' : 'Не удалось поставить напоминание');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in reminderChoices)
            SheetChip(
              label: m == 60 ? 'За час' : 'За $m мин',
              selected: !_ownTime && _minutes == m,
              onTap: () => setState(() {
                _ownTime = false;
                _minutes = m;
                _error = null;
              }),
            ),
          SheetChip(label: 'Своё время', selected: _ownTime, onTap: () => setState(() => _ownTime = true)),
        ]),
        if (_ownTime) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _custom,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: T.body.copyWith(color: c.text),
            cursorColor: c.link,
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              hintText: 'За сколько минут',
              hintStyle: T.body.copyWith(color: c.muted),
              suffixText: 'мин',
              errorText: _error,
              filled: true,
              fillColor: c.surface,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
        ] else if (_error != null)
          Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: T.caption.copyWith(color: c.danger))),
        const SizedBox(height: 20),
        SheetButton(label: 'Поставить', enabled: !_busy, onTap: _done),
      ],
    );
  }
}
