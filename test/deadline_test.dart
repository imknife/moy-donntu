import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lab/data/native_bridge.dart';
import 'package:flutter_lab/data/store.dart';
import 'package:flutter_lab/domain/deadline.dart';
import 'package:flutter_lab/ui/deadline_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support.dart';

Deadline make(String id, String due, {String? time, bool done = false, int? remind}) => Deadline(id: id, title: 'Работа $id', due: due, createdAt: '2026-10-20T10:00:00Z', time: time, done: done, remindMinutes: remind);

class _CancelRecorder extends NoNativeBridge {
  _CancelRecorder();
  final List<int> cancelled = [];
  final List<int> scheduled = [];

  @override
  bool get available => true;

  @override
  Future<void> cancelManual(int id) async => cancelled.add(id);

  @override
  Future<bool> scheduleManual(int id, int at, String title, String body) async {
    scheduled.add(id);
    return true;
  }
}

void main() {
  final today = DateTime.utc(2026, 10, 29);

  test('идентификатор напоминания дедлайна стабилен: FNV-1a 32 бита, младшие 16', () {
    expect(deadlineNotificationId(''), 40389);
    expect(deadlineNotificationId('a'), 10540);
    expect(deadlineNotificationId('abc'), 59659);
    expect(deadlineNotificationId('d1'), 5094);
    expect(deadlineNotificationId('deadline-1'), 59259);
    expect(deadlineNotificationId('Дедлайн'), 4823);
    expect(deadlineNotificationId('d1'), deadlineNotificationId('d1'));
    for (final id in ['x', 'long-identifier-0123456789', 'Дедлайн']) {
      expect(deadlineNotificationId(id), inInclusiveRange(0, 0xFFFF));
    }
  });

  test('отмена напоминания снимает и новый, и прежний идентификатор', () async {
    final bridge = _CancelRecorder();
    final c = await makeController(group: 'ПИ-25а', subgroup: 1, native: bridge);
    await cancelDeadlineReminder(c, 'deadline-1');
    expect(bridge.cancelled, containsAll([deadlineNotificationId('deadline-1'), legacyDeadlineNotificationId('deadline-1')]));
  });

  test('пересинхронизация снимает прежний идентификатор и ставит новый', () async {
    final bridge = _CancelRecorder();
    final c = await makeController(group: 'ПИ-25а', subgroup: 1, native: bridge);
    final future = DateTime.now().add(const Duration(days: 30));
    final due = '${future.year}-${future.month.toString().padLeft(2, '0')}-${future.day.toString().padLeft(2, '0')}';
    await syncDeadlineReminder(c, make('deadline-1', due, remind: 60));
    expect(bridge.cancelled, contains(legacyDeadlineNotificationId('deadline-1')));
    expect(bridge.scheduled, [deadlineNotificationId('deadline-1')]);
  });

  test('корзины: просрочено, сегодня, неделя, позже, выполнено', () {
    expect(deadlineBucket(make('a', '2026-10-28'), today, 600), DeadlineBucket.overdue);
    expect(deadlineBucket(make('b', '2026-10-29', time: '23:00'), today, 600), DeadlineBucket.today);
    expect(deadlineBucket(make('c', '2026-10-29', time: '08:00'), today, 600), DeadlineBucket.overdue);
    expect(deadlineBucket(make('d', '2026-11-03'), today, 600), DeadlineBucket.soon);
    expect(deadlineBucket(make('e', '2026-12-01'), today, 600), DeadlineBucket.later);
    expect(deadlineBucket(make('f', '2026-10-01', done: true), today, 600), DeadlineBucket.done);
  });

  test('подписи срока', () {
    expect(deadlineWhen(make('a', '2026-10-27'), today, 600), 'Просрочено на 2 дня');
    expect(deadlineWhen(make('a', '2026-10-28'), today, 600), 'Просрочено со вчера');
    expect(deadlineWhen(make('a', '2026-10-29', time: '18:00'), today, 600), 'Сегодня, 18:00');
    expect(deadlineWhen(make('a', '2026-10-30'), today, 600), 'Завтра');
    expect(deadlineWhen(make('a', '2026-12-05'), today, 600), '5 декабря');
  });

  test('группировка и порядок', () {
    final list = [make('1', '2026-11-02'), make('2', '2026-10-28'), make('3', '2026-10-29', time: '20:00'), make('4', '2026-10-31', done: true)];
    final groups = groupDeadlines(list, today, 600);
    expect(groups[DeadlineBucket.overdue]!.map((d) => d.id), ['2']);
    expect(groups[DeadlineBucket.today]!.map((d) => d.id), ['3']);
    expect(groups[DeadlineBucket.soon]!.map((d) => d.id), ['1']);
    expect(groups[DeadlineBucket.done]!.map((d) => d.id), ['4']);
    expect(openDeadlines(list), 3);
    expect(overdueDeadlines(list, today, 600), 1);
    expect(nextDeadline(list, today, 600)!.id, '3');
  });

  test('напоминание считается от времени сдачи по Москве', () {
    final d = make('a', '2026-10-30', time: '18:00', remind: 60);
    expect(deadlineTrigger(d), DateTime.utc(2026, 10, 30, 14, 0).millisecondsSinceEpoch);
    expect(deadlineTrigger(make('b', '2026-10-30', remind: 1440)), DateTime.utc(2026, 10, 29, 6, 0).millisecondsSinceEpoch);
    expect(deadlineTrigger(make('c', '2026-10-30')), isNull);
  });

  test('дедлайны сохраняются и читаются из хранилища', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.open();
    store.saveDeadline(make('x', '2026-11-01', time: '09:30', remind: 180));
    store.saveDeadline(make('x', '2026-11-02', time: '09:30', remind: 180));
    store.saveDeadline(make('y', '2026-11-05'));
    final again = AppStore.fromPreferences(await SharedPreferences.getInstance());
    expect(again.deadlines.value.map((d) => d.id), ['x', 'y']);
    expect(again.deadlines.value.first.due, '2026-11-02');
    expect(again.deadlines.value.first.remindMinutes, 180);
    again.removeDeadline('x');
    expect(AppStore.fromPreferences(await SharedPreferences.getInstance()).deadlines.value.map((d) => d.id), ['y']);
  });

  test('фильтры расписания сохраняются в настройках', () {
    final prefs = const Prefs().copyWith(hiddenKinds: ['lab'], showGaps: false);
    final back = Prefs.fromJson(prefs.toJson());
    expect(back.hiddenKinds, ['lab']);
    expect(back.showGaps, isFalse);
    expect(Prefs.fromJson(const {}).showGaps, isTrue);
  });
}
