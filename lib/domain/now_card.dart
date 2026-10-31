import 'campus.dart';
import 'schedule.dart';

enum NowCardKind { before, live, pause, window, done, dayoff, preview }

class NowCardModel {
  const NowCardModel({required this.kind, required this.title, this.lesson, this.countdown, this.countdownLabel, this.progress, this.walkTo, this.nextLesson});
  final NowCardKind kind;
  final String title;
  final DayLesson? lesson;
  final int? countdown;
  final String? countdownLabel;
  final double? progress;
  final int? walkTo;
  final DayLesson? nextLesson;
}

String _walkNote(List<DayLesson> items, DayLesson next, int to) {
  final index = items.indexOf(next);
  final prev = index > 0 ? items[index - 1] : null;
  final from = prev == null ? null : buildingOf(prev.lesson);
  final walk = from == null ? null : campusPathWalk(from, to) ?? campusWalk(from, to);
  return walk == null ? '' : ' · пешком ≈ ${walk.minutes} мин';
}

NowCardModel nowCardModel({required List<DayLesson> items, required double minute, required bool today, String? dayOffName}) {
  final off = dayOffName != null && dayOffName.isNotEmpty ? dayOffName : 'Свободный день';
  if (items.isEmpty) return NowCardModel(kind: NowCardKind.dayoff, title: off);
  if (!today) {
    return NowCardModel(kind: NowCardKind.preview, title: 'Первая пара в ${items.first.bell.start.replaceFirst(RegExp(r'^0'), '')}', lesson: items.first);
  }
  final state = nowState(items, minute);
  switch (state) {
    case NowBefore():
      return NowCardModel(kind: NowCardKind.before, title: 'Скоро первая пара', lesson: state.next, countdown: state.minutes, countdownLabel: 'до начала');
    case NowLive():
      return NowCardModel(kind: NowCardKind.live, title: 'Сейчас идёт', lesson: state.current, countdown: state.left, countdownLabel: 'до конца', progress: state.progress, nextLesson: state.next);
    case NowGap() when !state.window:
      final walk = state.gap.walkTo;
      return NowCardModel(
        kind: NowCardKind.pause,
        title: walk != null ? 'Перемена · переход в корпус $walk${_walkNote(items, state.next, walk)}' : 'Перемена',
        lesson: state.next,
        countdown: state.minutes,
        countdownLabel: 'до звонка',
        walkTo: walk,
      );
    case NowGap():
      return NowCardModel(kind: NowCardKind.window, title: 'Окно — время для себя', lesson: state.next, countdown: state.minutes, countdownLabel: 'до следующей пары');
    case NowDone():
      return const NowCardModel(kind: NowCardKind.done, title: 'На сегодня всё');
    case NowEmpty():
      return NowCardModel(kind: NowCardKind.dayoff, title: off);
  }
}

List<({String value, String unit})> countdownParts(num minutes) {
  final ceil = minutes.ceil();
  final m = ceil < 0 ? 0 : ceil;
  if (m < 60) return [(value: '$m', unit: 'мин')];
  return [(value: '${m ~/ 60}', unit: 'ч'), if (m % 60 != 0) (value: '${m % 60}', unit: 'мин')];
}
