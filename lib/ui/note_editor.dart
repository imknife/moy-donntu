import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/notes.dart';
import '../domain/study_tools.dart';
import 'common.dart';
import 'derived.dart';
import 'icons.dart';
import 'scope.dart';
import 'theme.dart';
import 'widgets.dart';
import 'type_settings.dart';

class NoteBody extends StatelessWidget {
  const NoteBody({super.key, required this.text, required this.onToggle, this.onlyTodo = false});
  final String text;
  final void Function(int index) onToggle;
  final bool onlyTodo;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final lines = parseLines(text).where((l) => (l.text.isNotEmpty || l.isTodo) && (!onlyTodo || l.isTodo)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final l in lines)
          if (l.isTodo)
            Tap(
              label: l.text,
              onTap: () => onToggle(l.index),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 36),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: l.checked ? c.link : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: l.checked ? c.link : c.muted, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: l.checked ? AppIcon('check', size: 14, color: c.onLink) : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(l.text, style: T.body.copyWith(color: l.checked ? c.muted : c.text, decoration: l.checked ? TextDecoration.lineThrough : null))),
                  ],
                ),
              ),
            )
          else
            Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(l.text, style: T.body.copyWith(color: c.text))),
      ],
    );
  }
}

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key, this.id, this.lessonKey, this.lessonDate, this.subject, this.kind, this.lessonParams});
  final String? id;
  final String? lessonKey;
  final String? lessonDate;
  final String? subject;
  final String? kind;
  final Map<String, String>? lessonParams;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final Note? _existing = widget.id == null ? null : context.app.store.notes.value.where((n) => n.id == widget.id).firstOrNull;
  late final TextEditingController _title = TextEditingController(text: _existing?.title ?? '');
  late final TextEditingController _text = TextEditingController(text: _existing?.text ?? '');
  late bool _pinned = _existing?.pinned ?? false;
  late final String _id = widget.id ?? 'n${DateTime.now().microsecondsSinceEpoch}';
  late String _previous = _text.text;
  Timer? _timer;
  bool _dirty = false;
  bool _removed = false;
  String _status = '';

  String? get _subject => _existing?.subject ?? widget.subject;

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
    _timer = Timer(const Duration(milliseconds: 600), () {
      _persist();
      if (mounted) setState(() => _status = 'Сохранено');
    });
    if (_status.isNotEmpty) setState(() => _status = '');
  }

  void _persist() {
    _dirty = false;
    if (_removed) return;
    final store = context.app.store;
    final title = _title.text.trim();
    if (title.isEmpty && _text.text.trim().isEmpty) return;
    store.saveNote(Note(
      id: _id,
      title: title,
      text: _text.text,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      lessonKey: _existing?.lessonKey ?? widget.lessonKey,
      lessonDate: _existing?.lessonDate ?? widget.lessonDate,
      subject: _subject,
      kind: _existing?.kind ?? widget.kind,
      pinned: _pinned,
    ));
  }

  void _onText(String value) {
    final next = autoContinue(_previous, value);
    if (next != value) _text.value = TextEditingValue(text: next, selection: TextSelection.collapsed(offset: next.length));
    _previous = next;
    _edited();
  }

  void _addItem() {
    final next = addChecklistItem(_text.text);
    _text.value = TextEditingValue(text: next, selection: TextSelection.collapsed(offset: next.length));
    _previous = next;
    _edited();
  }

  void _toggleLine(int index) {
    final next = toggleLine(_text.text, index);
    _text.value = TextEditingValue(text: next, selection: TextSelection.collapsed(offset: next.length));
    _previous = next;
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
    if (!mounted) return;
    context.app.store.removeNote(existing.id);
    Navigator.of(context).pop();
  }

  void _finish() {
    _timer?.cancel();
    _persist();
    _removed = true;
    Navigator.of(context).pop();
  }

  void _share() {
    final text = '${_title.text.trim().isEmpty ? noteTitleOf(_text.text) : _title.text.trim()}\n\n${_text.text}'.trim();
    Clipboard.setData(ClipboardData(text: text));
    showToast(context, 'Текст заметки скопирован');
  }

  String noteTitleOf(String text) => noteTitle(Note(id: '', title: '', text: text, updatedAt: ''));

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final date = _existing?.lessonDate ?? widget.lessonDate;
    final params = _existing == null ? widget.lessonParams : null;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            BackBar(title: 'Заметка', actions: [
              Tap(label: 'Готово', onTap: _finish, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Text('Готово'.cased, style: T.captionSemi.copyWith(color: c.link)))),
            ]),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  if (_subject != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: c.tint, borderRadius: BorderRadius.circular(18)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          AppIcon('schedule', size: 16, color: c.link),
                          const SizedBox(width: 6),
                          Flexible(child: Text('$_subject${date != null ? ' · ${humanDate(date)}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.captionMedium.copyWith(color: c.link))),
                        ]),
                      ),
                    ),
                  if (params != null) const SizedBox.shrink(),
                  const VGap(8),
                  TextField(
                    controller: _title,
                    onChanged: (_) => _edited(),
                    style: T.subject.copyWith(color: c.text),
                    cursorColor: c.link,
                    decoration: _decoration(c, 'Название (необязательно)'),
                  ),
                  const VGap(8),
                  TextField(
                    controller: _text,
                    onChanged: _onText,
                    minLines: 6,
                    maxLines: null,
                    style: T.body.copyWith(color: c.text, fontSize: 15),
                    cursorColor: c.link,
                    decoration: _decoration(c, 'Текст заметки'),
                  ),
                  ListenableBuilder(
                    listenable: _text,
                    builder: (context, _) {
                      final todo = progress(_text.text);
                      if (todo.total == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SurfaceCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Чеклист · ${todo.done} из ${todo.total}'.cased, style: T.caption.copyWith(color: c.muted)),
                            NoteBody(text: _text.text, onlyTodo: true, onToggle: _toggleLine),
                          ]),
                        ),
                      );
                    },
                  ),
                  const VGap(8),
                  Wrap(spacing: 8, runSpacing: 8, children: [PillButton(label: 'Чеклист', icon: 'checklist', onTap: _addItem)]),
                  const VGap(8),
                  Row(children: [
                    Expanded(child: Text(_status.isEmpty ? 'Сохраняется само' : _status, style: T.caption.copyWith(color: c.muted))),
                    _IconAction(icon: 'star', label: _pinned ? 'Открепить заметку' : 'Закрепить заметку', active: _pinned, onTap: () => setState(() {
                          _pinned = !_pinned;
                          _edited();
                        })),
                    _IconAction(icon: 'link', label: 'Скопировать заметку', onTap: _share),
                    if (_existing != null) _IconAction(icon: 'trash', label: 'Удалить заметку', onTap: _delete),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(Pal c, String hint) => InputDecoration(
        hintText: hint,
        hintStyle: T.body.copyWith(color: c.muted),
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.all(14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      );
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.label, required this.onTap, this.active = false});
  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Tap(
      label: label,
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(color: active ? c.tint : Colors.transparent, borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.center,
        child: AppIcon(icon, size: 20, color: active ? c.link : c.text),
      ),
    );
  }
}
