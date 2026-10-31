import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/schedule_model.dart';
import '../domain/notes.dart';
import '../domain/schedule.dart';
import '../domain/time_utils.dart';
import 'derived.dart';
import 'icons.dart';
import 'theme.dart';
import 'type_settings.dart';

String kindGlyph(String kind) => switch (kind) {
      'lab' => 'lab',
      'practice' => 'practice',
      'exam' || 'credit' => 'exam',
      _ => 'lecture',
    };

int _phase(DayLesson it, int minute) {
  if (minute < it.bell.startMinutes) return 0;
  if (minute >= it.bell.endMinutes) return 2;
  return 1000 + minute;
}

class LessonCard extends StatelessWidget {
  const LessonCard({super.key, required this.row, required this.names, required this.clock, required this.notes, required this.isToday, required this.onOpen});
  final CardRow row;
  final Map<String, String> names;
  final MskClock clock;
  final ValueListenable<List<Note>> notes;
  final bool isToday;
  final void Function(CardRow row) onOpen;

  @override
  Widget build(BuildContext context) {
    final card = isToday
        ? Derived<int>(
            listenable: clock,
            read: () => _phase(row.item, clock.value.minute),
            builder: (context, phase) => _CardBody(row: row, names: names, notes: notes, phase: phase, minute: clock.value.minute),
          )
        : _CardBody(row: row, names: names, notes: notes, phase: 0, minute: -1);
    return Tap(label: '${shortTime(row.item.bell.start)}–${shortTime(row.item.bell.end)}, ${kindLabel[row.item.lesson.kind]}, ${row.item.lesson.subject}', onTap: () => onOpen(row), child: card);
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({required this.row, required this.names, required this.notes, required this.phase, required this.minute});
  final CardRow row;
  final Map<String, String> names;
  final ValueListenable<List<Note>> notes;
  final int phase;
  final int minute;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final item = row.item;
    final live = phase >= 1000;
    final past = phase == 2;
    final lesson = item.lesson;
    final rooms = roomsLabel(lesson);
    final teacher = teachersLabel(lesson, names);
    final extra = changeChip(item);
    final roomColor = isReplaced(item) ? c.link : c.muted;
    final progress = live ? ((minute - item.bell.startMinutes) / (item.bell.endMinutes - item.bell.startMinutes)).clamp(0.0, 1.0) : 0.0;
    return RepaintBoundary(
      child: Opacity(
        opacity: past ? 0.5 : 1,
        child: Container(
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 38,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shortTime(item.bell.start), style: T.captionSemi.copyWith(color: live ? c.link : (past ? c.muted : c.text))),
                    const SizedBox(height: 2),
                    Text(shortTime(item.bell.end), style: T.micro.copyWith(color: c.muted)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: SizedBox(
                width: 26,
                height: 26,
                child: CustomPaint(
                  painter: live ? _RingPainter(progress, c.hairline, c.link) : null,
                  child: Center(child: AppIcon(kindGlyph(lesson.kind), size: 16, color: live ? c.link : c.muted)),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lesson.subject, maxLines: 3, overflow: TextOverflow.ellipsis, style: T.subject.copyWith(color: past ? c.muted : c.text)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      KindChip(kind: lesson.kind),
                      if (rooms.isNotEmpty) RoomLabel(text: rooms, color: roomColor, background: c.soft),
                      if (extra != null) Text(extra, style: T.microSemi.copyWith(color: c.link)),
                    ],
                  ),
                  if (teacher.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(teacher, style: T.micro.copyWith(color: c.muted)),
                  ],
                  if (live) ...[
                    const SizedBox(height: 4),
                    Text('Идёт · ещё ${formatDuration(item.bell.endMinutes - minute)}'.cased, style: T.microMedium.copyWith(color: c.link)),
                  ],
                  _NoteMarker(notes: notes, lessonKey: item.key, date: ymd(row.date)),
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

class RoomLabel extends StatelessWidget {
  const RoomLabel({super.key, required this.text, required this.color, required this.background});
  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final placed = text != noRoomLabel;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(7)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (placed) ...[
            AppIcon('pin', size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(child: Text(text, style: T.micro.copyWith(color: color))),
        ],
      ),
    );
  }
}

class _NoteMarker extends StatelessWidget {
  const _NoteMarker({required this.notes, required this.lessonKey, required this.date});
  final ValueListenable<List<Note>> notes;
  final String lessonKey;
  final String date;

  String _read() {
    final list = notesForLesson(notes.value, lessonKey, date);
    return list.isEmpty ? '' : noteMarker(list);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Derived<String>(
      listenable: notes,
      read: _read,
      builder: (context, marker) => marker.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  AppIcon('note', size: 12, color: c.link),
                  const SizedBox(width: 4),
                  Expanded(child: Text(marker, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caption.copyWith(color: c.link))),
                ],
              ),
            ),
    );
  }
}

class KindChip extends StatelessWidget {
  const KindChip({super.key, required this.kind, this.solid = false});
  final String kind;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final tone = c.kindTone(kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: solid ? tone?.$1 ?? c.text : tone?.$2 ?? c.soft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(TypeSettings.caps(kindLabel[kind] ?? ''), style: T.overline.copyWith(color: solid ? c.surface : tone?.$1 ?? c.text)),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.track, this.arc);
  final double progress;
  final Color track, arc;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2 - 1;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: radius);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(rect.center, radius, p..color = track);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, p..color = arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.track != track || old.arc != arc;
}

class GapTile extends StatelessWidget {
  const GapTile({super.key, required this.minutes});
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(height: 1, thickness: 1, color: c.hairline)),
          const SizedBox(width: 12),
          AppIcon('coffee', size: 18, color: c.muted),
          const SizedBox(width: 8),
          Text('окно · ${formatDuration(minutes)}'.cased, maxLines: 1, softWrap: false, style: T.caption.copyWith(height: 16 / 13, color: c.muted)),
          const SizedBox(width: 12),
          Expanded(child: Divider(height: 1, thickness: 1, color: c.hairline)),
        ],
      ),
    );
  }
}

class CancelledCard extends StatelessWidget {
  const CancelledCard({super.key, required this.row, required this.onOpen});
  final CancelledRow row;
  final void Function(CancelledRow row) onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final note = row.lesson.note;
    final bell = row.lesson.bell;
    return Tap(
      label: '${row.lesson.num}-я пара отменена',
      onTap: () => onOpen(row),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 38,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shortTime(bell.start), style: T.captionSemi.copyWith(color: c.muted, decoration: TextDecoration.lineThrough)),
                    const SizedBox(height: 2),
                    Text(shortTime(bell.end), style: T.micro.copyWith(color: c.muted, decoration: TextDecoration.lineThrough)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.lesson.subject, maxLines: 3, overflow: TextOverflow.ellipsis, style: T.subject.copyWith(color: c.muted, decoration: TextDecoration.lineThrough, decorationColor: c.muted)),
                  const SizedBox(height: 4),
                  Text('${row.lesson.num}-я пара отменена${note != null && note.isNotEmpty ? ' · $note' : ''}'.cased, style: T.micro.copyWith(color: c.danger)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
