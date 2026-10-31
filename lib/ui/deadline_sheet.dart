import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/app_controller.dart';
import '../domain/deadline.dart';
import '../domain/time_utils.dart';
import 'common.dart';
import 'derived.dart';
import 'lesson_picker.dart';
import 'scope.dart';
import 'sheet.dart';
import 'theme.dart';
import 'type_settings.dart';

const deadlineReminders = <(String, int?)>[('Без напоминания', null), ('За час', 60), ('За 3 часа', 180), ('За день', 1440)];

int deadlineNotificationId(String id) {
  var hash = 0x811C9DC5;
  for (final byte in utf8.encode(id)) {
    hash = ((hash ^ byte) * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0xFFFF;
}

int legacyDeadlineNotificationId(String id) => Object.hash('deadline', id) & 0xFFFF;

Future<void> cancelDeadlineReminder(AppController controller, String id) async {
  final native = controller.native;
  await native.cancelManual(deadlineNotificationId(id));
  final legacy = legacyDeadlineNotificationId(id);
  if (legacy != deadlineNotificationId(id)) await native.cancelManual(legacy);
}

int? deadlineTrigger(Deadline d) {
  final minutes = d.remindMinutes;
  final due = d.dueDate;
  if (minutes == null || due == null) return null;
  final time = d.time == null ? '09:00' : (d.time!.length == 4 ? '0${d.time}' : d.time!);
  final at = DateTime.tryParse('${d.due}T$time:00+03:00');
  return at == null ? null : at.millisecondsSinceEpoch - minutes * 60000;
}

Future<void> syncDeadlineReminder(AppController controller, Deadline d) async {
  final native = controller.native;
  if (!native.available) return;
  final id = deadlineNotificationId(d.id);
  await cancelDeadlineReminder(controller, d.id);
  final trigger = deadlineTrigger(d);
  if (d.done || trigger == null || trigger <= DateTime.now().millisecondsSinceEpoch) return;
  await native.requestNotifications();
  final subject = d.subject == null || d.subject!.isEmpty ? '' : ' · ${d.subject}';
  final due = d.dueDate;
  final when = due == null ? '' : '${formatDayDate(due)}${d.time == null ? '' : ', ${shortTime(d.time!)}'}';
  await native.scheduleManual(id, trigger, d.title, 'Срок: $when$subject');
}

Future<void> showDeadlineSheet(BuildContext context, {String? id, String? lessonKey, String? lessonDate, String? subject, String? kind, String? due}) {
  final controller = context.app;
  return showAppSheet<void>(
    context,
    title: id == null ? 'Новый дедлайн' : 'Дедлайн',
    builder: (_) => DeadlineSheetBody(controller: controller, id: id, lessonKey: lessonKey, lessonDate: lessonDate, subject: subject, kind: kind, due: due),
  );
}

class DeadlineSheetBody extends StatefulWidget {
  const DeadlineSheetBody({super.key, required this.controller, this.id, this.lessonKey, this.lessonDate, this.subject, this.kind, this.due});
  final AppController controller;
  final String? id;
  final String? lessonKey;
  final String? lessonDate;
  final String? subject;
  final String? kind;
  final String? due;

  @override
  State<DeadlineSheetBody> createState() => _DeadlineSheetBodyState();
}

class _DeadlineSheetBodyState extends State<DeadlineSheetBody> {
  late final Deadline? _existing = widget.id == null ? null : widget.controller.store.deadlines.value.where((d) => d.id == widget.id).firstOrNull;
  late final TextEditingController _title = TextEditingController(text: _existing?.title ?? '');
  late final TextEditingController _details = TextEditingController(text: _existing?.details ?? '');
  late String _due = _existing?.due ?? widget.due ?? ymd(addDays(widget.controller.clock.value.today, 1));
  late String? _time = _existing?.time;
  late int? _remind = _existing?.remindMinutes;
  late String? _lessonKey = _existing?.lessonKey ?? widget.lessonKey;
  late String? _lessonDate = _existing?.lessonDate ?? widget.lessonDate;
  late String? _subject = _existing?.subject ?? widget.subject;
  late String? _kind = _existing?.kind ?? widget.kind;
  bool _busy = false;

  DateTime get _today => widget.controller.clock.value.today;

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final current = parseYmd(_due) ?? _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(current.year, current.month, current.day),
      firstDate: DateTime(_today.year, _today.month, _today.day).subtract(const Duration(days: 30)),
      lastDate: DateTime(_today.year + 2, 12, 31),
      helpText: 'Срок сдачи',
    );
    if (picked == null || !mounted) return;
    setState(() => _due = ymd(DateTime.utc(picked.year, picked.month, picked.day)));
  }

  Future<void> _pickTime() async {
    final parts = (_time ?? '09:00').split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.tryParse(parts.first) ?? 9, minute: int.tryParse(parts.last) ?? 0),
      helpText: 'Время сдачи',
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked == null || !mounted) return;
    setState(() => _time = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
  }

  Future<void> _attach() async {
    final picked = await pickLesson(context, widget.controller, days: 21);
    if (picked == null || !mounted) return;
    setState(() {
      _lessonKey = picked.key;
      _lessonDate = picked.date;
      _subject = picked.subject;
      _kind = picked.kind;
    });
  }

  void _detach() => setState(() {
        _lessonKey = null;
        _lessonDate = null;
        _subject = null;
        _kind = null;
      });

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    setState(() => _busy = true);
    final item = Deadline(
      id: _existing?.id ?? 'd${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      due: _due,
      createdAt: _existing?.createdAt ?? DateTime.now().toUtc().toIso8601String(),
      time: _time,
      subject: _subject,
      lessonKey: _lessonKey,
      lessonDate: _lessonDate,
      kind: _kind,
      details: _details.text.trim(),
      done: _existing?.done ?? false,
      remindMinutes: _remind,
    );
    widget.controller.store.saveDeadline(item);
    await syncDeadlineReminder(widget.controller, item);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final existing = _existing;
    if (existing == null) return;
    if (!await confirm(context, title: 'Удалить дедлайн?')) return;
    widget.controller.store.removeDeadline(existing.id);
    await cancelDeadlineReminder(widget.controller, existing.id);
    if (mounted) Navigator.of(context).pop();
  }

  InputDecoration _decoration(Pal c, String hint) => InputDecoration(
        hintText: hint,
        hintStyle: T.body.copyWith(color: c.muted),
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.all(14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final today = _today;
    final tomorrow = addDays(today, 1);
    final week = addDays(today, 7);
    final dueDate = parseYmd(_due);
    final custom = _due != ymd(today) && _due != ymd(tomorrow) && _due != ymd(week);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _title,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          style: T.subject.copyWith(color: c.text),
          cursorColor: c.link,
          decoration: _decoration(c, 'Что нужно сдать'),
        ),
        const SheetLabel('Срок'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          SheetChip(label: 'Сегодня', selected: _due == ymd(today), onTap: () => setState(() => _due = ymd(today))),
          SheetChip(label: 'Завтра', selected: _due == ymd(tomorrow), onTap: () => setState(() => _due = ymd(tomorrow))),
          SheetChip(label: 'Через неделю', selected: _due == ymd(week), onTap: () => setState(() => _due = ymd(week))),
          SheetChip(label: custom && dueDate != null ? formatDayDate(dueDate) : 'Другая дата', selected: custom, onTap: _pickDate),
        ]),
        const SizedBox(height: 12),
        SheetGroup(children: [
          SheetRow(
            title: 'Время',
            detail: _time == null ? 'Не указано' : shortTime(_time!),
            onTap: _pickTime,
            trailing: _time == null ? null : Tap(label: 'Убрать время', onTap: () => setState(() => _time = null), child: Padding(padding: const EdgeInsets.all(6), child: Text('Убрать'.cased, style: T.captionSemi.copyWith(color: c.link)))),
          ),
          LessonAttachRow(subject: _subject, date: _lessonDate, onPick: _attach, onClear: _detach),
        ]),
        if (widget.controller.native.available) ...[
          const SheetLabel('Напоминание'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final r in deadlineReminders) SheetChip(label: r.$1, selected: _remind == r.$2, onTap: () => setState(() => _remind = r.$2)),
          ]),
        ],
        const SheetLabel('Описание'),
        TextField(
          controller: _details,
          minLines: 2,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          style: T.body.copyWith(color: c.text),
          cursorColor: c.link,
          decoration: _decoration(c, 'Детали, ссылка, номер варианта'),
        ),
        const SizedBox(height: 20),
        SheetButton(label: 'Сохранить', enabled: _title.text.trim().isNotEmpty && !_busy, onTap: _save),
        if (_existing != null)
          Tap(
            label: 'Удалить дедлайн',
            onTap: _delete,
            child: Container(height: 48, alignment: Alignment.center, child: Text('Удалить дедлайн'.cased, style: T.captionSemi.copyWith(color: c.danger))),
          ),
      ],
    );
  }
}
