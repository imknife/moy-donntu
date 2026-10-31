class ReminderModel {
  const ReminderModel.valid(this.minutes, this.triggerMillis)
      : valid = true,
        error = null;
  const ReminderModel.invalid(this.error)
      : valid = false,
        minutes = 0,
        triggerMillis = 0;
  final bool valid;
  final int minutes;
  final int triggerMillis;
  final String? error;
}

final _dateShape = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final _timeShape = RegExp(r'^(?:[01]?\d|2[0-3]):[0-5]\d$');

ReminderModel reminderModel(String date, String start, String value, int nowMillis) {
  final minutes = int.tryParse(value);
  if (!RegExp(r'^\d+$').hasMatch(value) || minutes == null || minutes < 0 || minutes > 1440) {
    return const ReminderModel.invalid('Укажите целое число от 0 до 1440 минут');
  }
  final day = _dateShape.hasMatch(date) ? DateTime.tryParse('${date}T12:00:00Z') : null;
  if (day == null || day.toIso8601String().substring(0, 10) != date || !_timeShape.hasMatch(start)) {
    return const ReminderModel.invalid('Выберите занятие с корректной датой и временем');
  }
  final padded = start.length == 4 ? '0$start' : start;
  final lesson = DateTime.parse('${date}T$padded:00+03:00').millisecondsSinceEpoch;
  final trigger = lesson - minutes * 60000;
  if (trigger <= nowMillis) return const ReminderModel.invalid('Время напоминания уже прошло. Уменьшите интервал или выберите будущую пару');
  return ReminderModel.valid(minutes, trigger);
}
