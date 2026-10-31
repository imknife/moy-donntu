import 'package:flutter/material.dart';

import '../domain/notes.dart';
import '../domain/time_utils.dart';
import 'common.dart';
import 'derived.dart';
import 'icons.dart';
import 'note_sheet.dart';
import 'scope.dart';
import 'theme.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final TextEditingController _query = TextEditingController();
  String _filter = noteFilters.first;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  final Set<String> _picked = {};

  void _pick(String id) => setState(() {
        if (!_picked.add(id)) _picked.remove(id);
      });

  Note _withPinned(Note note, bool pinned) => Note(
        id: note.id,
        title: note.title,
        text: note.text,
        updatedAt: note.updatedAt,
        lessonKey: note.lessonKey,
        lessonDate: note.lessonDate,
        subject: note.subject,
        kind: note.kind,
        pinned: pinned,
      );

  void _pin() {
    final store = context.app.store;
    final chosen = [for (final n in store.notes.value) if (_picked.contains(n.id)) n];
    final pin = chosen.any((n) => !n.pinned);
    for (final n in chosen) {
      store.saveNote(_withPinned(n, pin));
    }
    setState(_picked.clear);
  }

  Future<void> _delete() async {
    final store = context.app.store;
    final ids = {..._picked};
    final count = ids.length;
    final ok = await confirm(context, title: 'Удалить $count ${plural(count, 'заметку', 'заметки', 'заметок')}?');
    if (!ok || !mounted) return;
    store.removeNotes(ids);
    setState(_picked.clear);
  }

  @override
  Widget build(BuildContext context) {
    final selecting = _picked.isNotEmpty;
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_picked.clear);
      },
      child: _page(context, selecting),
    );
  }

  Widget _page(BuildContext context, bool selecting) {
    final c = context.pal;
    final store = context.app.store;
    return PageScaffold(
      title: selecting ? 'Выбрано: ${_picked.length}' : 'Заметки',
      actions: selecting
          ? [
              Tap(label: 'Закрепить выбранные', onTap: _pin, child: SizedBox(width: 48, height: 56, child: Center(child: AppIcon('star', size: 22, color: c.text)))),
              Tap(
                label: 'Выбрать все',
                onTap: () => setState(() => _picked.addAll([for (final n in filterNotes(store.notes.value, _filter, _query.text)) n.id])),
                child: SizedBox(height: 56, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Center(child: Text('Все', style: T.captionSemi.copyWith(color: c.link))))),
              ),
              Tap(label: 'Удалить выбранные', onTap: _delete, child: SizedBox(width: 52, height: 56, child: Center(child: AppIcon('trash', size: 22, color: c.danger)))),
            ]
          : const [],
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      overlay: selecting
          ? null
          : Positioned(
              right: 16,
              bottom: 16,
              child: Tap(
                label: 'Новая заметка',
                onTap: () => showNoteSheet(context),
                child: Container(width: 56, height: 56, decoration: BoxDecoration(color: c.segmentOn, borderRadius: BorderRadius.circular(28)), alignment: Alignment.center, child: AppIcon('plus', size: 26, color: c.segmentOnText)),
              ),
            ),
      children: [
        ValueListenableBuilder<List<Note>>(
          valueListenable: store.notes,
          builder: (context, notes, _) => ListenableBuilder(
            listenable: _query,
            builder: (context, _) {
              final now = toMsk(DateTime.now());
              final rows = buildNoteRows(filterNotes(notes, _filter, _query.text), now);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (notes.isNotEmpty) ...[
                    SearchBox(controller: _query, hint: 'Поиск заметок'),
                    const VGap(8),
                    ChipRow(options: noteFilters, value: _filter, onChanged: (v) => setState(() => _filter = v)),
                    const VGap(8),
                  ],
                  if (rows.isEmpty)
                    notes.isNotEmpty
                        ? EmptyBox(icon: 'search', title: 'Ничего не нашлось', text: 'Попробуйте другой запрос или фильтр.', actionLabel: 'Сбросить', onAction: () => setState(() {
                              _query.clear();
                              _filter = noteFilters.first;
                            }))
                        : EmptyBox(icon: 'note', title: 'Заметок нет', actionLabel: 'Добавить', onAction: () => showNoteSheet(context)),
                  for (final row in rows)
                    switch (row) {
                      NoteHeaderRow() => Padding(padding: const EdgeInsets.only(top: 8, bottom: 4), child: Text(row.title, style: T.caption.copyWith(color: c.muted))),
                      NoteItemRow() => Padding(padding: const EdgeInsets.only(bottom: 8), child: _NoteCard(note: row.note, now: now, selecting: selecting, selected: _picked.contains(row.note.id), onPick: () => _pick(row.note.id))),
                    },
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.now, required this.selecting, required this.selected, required this.onPick});
  final Note note;
  final DateTime now;
  final bool selecting;
  final bool selected;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final tag = noteKindTag(note.kind);
    final preview = notePreview(note);
    final todo = progress(note.text);
    final meta = [noteDateLabel(note.updatedAt, now), note.subject].where((e) => e != null && e.isNotEmpty).join(' · ');
    return GestureDetector(
      onLongPress: onPick,
      child: Tap(
        label: noteTitle(note),
        onTap: selecting ? onPick : () => showNoteSheet(context, id: note.id),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: selected ? c.tint : c.surface, borderRadius: BorderRadius.circular(16)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: selected ? c.link : (tag.isNotEmpty ? c.tint : c.soft), borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: selected
                    ? AppIcon('check', size: 20, color: c.onLink)
                    : (tag.isNotEmpty ? Text(tag, style: T.overline.copyWith(color: c.link)) : AppIcon(note.lessonKey != null ? 'note' : 'pencil', size: 20, color: c.link)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(noteTitle(note), maxLines: 1, overflow: TextOverflow.ellipsis, style: T.subject.copyWith(color: c.text, fontWeight: FontWeight.w600))),
                      if (note.pinned) AppIcon('star', size: 14, color: c.link),
                    ]),
                    if (meta.isNotEmpty) Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.micro.copyWith(color: c.muted)),
                    if (preview.isNotEmpty) Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.body.copyWith(color: c.muted)),
                    if (todo.total > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(children: [AppIcon('checklist', size: 14, color: c.muted), const SizedBox(width: 4), Text('${todo.done}/${todo.total}', style: T.micro.copyWith(color: c.muted))]),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
