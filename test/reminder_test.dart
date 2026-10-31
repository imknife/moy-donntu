import 'package:flutter_lab/domain/reminder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.parse('2026-10-29T06:00:00Z').millisecondsSinceEpoch;

  test('напоминание считается от московского времени пары', () {
    final model = reminderModel('2026-10-29', '9:55', '15', now);
    expect(model.valid, isTrue);
    expect(model.minutes, 15);
    expect(model.triggerMillis, DateTime.parse('2026-10-29T06:40:00Z').millisecondsSinceEpoch);
  });

  test('прошедшее время и неверные значения отклоняются', () {
    expect(reminderModel('2026-10-29', '9:55', '300', now).valid, isFalse);
    expect(reminderModel('2026-10-29', '9:55', '', now).valid, isFalse);
    expect(reminderModel('2026-10-29', '9:55', '-5', now).valid, isFalse);
    expect(reminderModel('2026-10-29', '9:55', '1441', now).valid, isFalse);
    expect(reminderModel('2026-02-30', '9:55', '5', now).valid, isFalse);
    expect(reminderModel('2026-10-29', '25:00', '5', now).valid, isFalse);
  });
}
