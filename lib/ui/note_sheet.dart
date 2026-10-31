import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_controller.dart';
import '../domain/notes.dart';
import 'common.dart';
import 'derived.dart';
import 'lesson_picker.dart';
import 'note_editor.dart';
import 'scope.dart';
import 'sheet.dart';
import 'theme.dart';
import 'type_settings.dart';

Future<void> showNoteSheet(BuildContext context, {String? id, String? lessonKey, String? lessonDate, String? subject, String? kind}) {
  final controller = context.app;
  return showAppSheet<void>(
    context,
    title: id == null ? 'Новая заметка' : 'Заметка',
    builder: (_) => NoteSheetBody(controller: controller, id: id, lessonKey: lessonKey, lessonDate: lessonDate, subject: subject, kind: kind),
  );
}

class NoteSheetBody extends StatefulWidget {
  const NoteSheetBody({super.key, required this.controller, this.id, this.lessonKey, this.lessonDate, this.subject, this.kind});
  final AppController controller;
  final String? id;
  final String? lessonKey;
  final String? lessonDate;
  final String? subject;
  final String? kind;

  @override
  State<NoteSheetBody> createState() => _NoteSheetBodyState();
}

class _NoteSheetBodyState extends State<NoteSheetBody> {
  late final Note? _existing = widget.id == null ? null : widget.controller.store.notes.value.where((n) => n.id == widget.id).firstOrNull;
  late final TextEditingController _title = TextEditingController(text: _existing?.title ?? '');
  late final TextEditingController _text = TextEditingController(text: _existing?.text ?? '');
  late bool _pinned = _existing?.pinned ?? false;
  late String? _lessonKey = _existing?.lessonKey ?? widget.lessonKey;
  late String? _lessonDate = _existing?.lessonDate ?? widget.lessonDate;
  late String? _subject = _existing?.subject ?? widget.subject;
  late String? _kind = _existing?.kind ?? widget.kind;
  late final String _id = widget.id ?? 'n${DateTime.now().microsecondsSinceEpoch}';
  late String _previous = _text.text;
  Timer? _timer;
  bool _dirty = false;
  bool _removed = false;

  @override
  void dispose() {
    _timer?.cancel();
    if (_dirty) _persist();
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  void _edited() {
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 600), _persist);
  }

  void _persist() {
    _dirty = false;
    if (_removed) return;
    final title = _title.text.trim();
    if (title.isEmpty && _text.text.trim().isEmpty) return;
    widget.controller.store.saveNote(Note(
      id: _id,
      title: title,
      text: _text.text,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      lessonKey: _lessonKey,
      lessonDate: _lessonDate,
      subject: _subject,
      kind: _kind,
      pinned: _pinned,
    ));
  }

  void _onText(String value) {
    final next = autoContinue(_previous, value);
    if (next != value) _text.value = TextEditingValue(text: next, selection: TextSelection.collapsed(offset: next.length));
    _previous = next;
    _edited();
  }

  void _setText(String next) {
    _text.value = TextEditingValue(text: next, selection: TextSelection.collapsed(offset: next.length));
    _previous = next;
    _edited();
  }

  Future<void> _attach() async {
    final picked = await pickLesson(context, widget.controller);
    if (picked == null || !mounted) return;
    setState(() {
      _lessonKey = picked.key;
      _lessonDate = picked.date;
      _subject = picked.subject;
      _kind = picked.kind;
    });
    _edited();
  }

  void _detach() {
    setState(() {
      _lessonKey = null;
      _lessonDate = null;
      _subject = null;
      _kind = null;
    });
    _edited();
  }

  Future<void> _delete() async {
    final existing = _existing;
    if (existing == null) {
      Navigator.of(context).pop();
      return;
    }
    if (!await confirm(context, title: 'Удалить заметку?')) return;
    _removed = true;
    widget.controller.store.removeNote(existing.id);
    if (mounted) Navigator.of(context).pop();
  }

  void _finish() {
    _timer?.cancel();
    _persist();
    _dirty = false;
    Navigator.of(context).pop();
  }

  void _copy() {
    final title = _title.text.trim();
    Clipboard.setData(ClipboardData(text: '${title.isEmpty ? noteTitle(Note(id: '', title: '', text: _text.text, updatedAt: '')) : title}\n\n${_text.text}'.trim()));
    showToast(context, 'Текст заметки скопирован');
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(controller: _title, onChanged: (_) => _edited(), textCapitalization: TextCapitalization.sentences, style: T.subject.copyWith(color: c.text), cursorColor: c.link, decoration: _decoration(c, 'Название (необязательно)')),
        const SizedBox(height: 8),
        TextField(
          controller: _text,
          onChanged: _onText,
          minLines: 5,
          maxLines: 10,
          textCapitalization: TextCapitalization.sentences,
          style: T.body.copyWith(color: c.text, fontSize: 15),
          cursorColor: c.link,
          decoration: _decoration(c, 'Что важно помнить…'),
        ),
        ListenableBuilder(
          listenable: _text,
          builder: (context, _) {
            final todo = progress(_text.text);
            if (todo.total == 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Чеклист · ${todo.done} из ${todo.total}'.cased, style: T.caption.copyWith(color: c.muted)),
                  NoteBody(text: _text.text, onlyTodo: true, onToggle: (i) => _setText(toggleLine(_text.text, i))),
                ]),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          SheetChip(label: 'Чеклист', selected: false, onTap: () => _setText(addChecklistItem(_text.text))),
          SheetChip(label: _pinned ? 'Закреплена' : 'Закрепить', selected: _pinned, onTap: () => setState(() {
                _pinned = !_pinned;
                _edited();
              })),
          SheetChip(label: 'Копировать', selected: false, onTap: _copy),
        ]),
        SheetGroup(label: 'Привязка', children: [
          LessonAttachRow(subject: _subject, date: _lessonDate, onPick: _attach, onClear: _detach),
        ]),
        const SizedBox(height: 16),
        SheetButton(label: 'Готово', onTap: _finish),
        if (_existing != null)
          Tap(
            label: 'Удалить заметку',
            onTap: _delete,
            child: Container(height: 48, alignment: Alignment.center, child: Text('Удалить заметку'.cased, style: T.captionSemi.copyWith(color: c.danger))),
          ),
      ],
    );
  }
}
