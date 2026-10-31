import 'package:flutter_lab/data/native_bridge.dart';
import 'package:flutter_lab/data/store.dart';
import 'package:flutter_lab/data/widget_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

class RecordingBridge implements NativeBridge {
  final List<String> sent = [];

  @override
  bool get available => true;

  @override
  Future<bool> sync(String snapshot) async {
    sent.add(snapshot);
    return true;
  }

  @override
  Future<void> resume() async {}

  @override
  Future<NativeStatus> status() async => const NativeStatus();

  @override
  Future<void> requestNotifications() async {}

  @override
  Future<bool> openSettings(String target) async => true;

  @override
  Future<bool> openCalendarFile(String path) async => true;

  @override
  Future<bool> scheduleManual(int id, int at, String title, String body) async => true;

  @override
  Future<void> cancelManual(int id) async {}
}

void main() {
  test('снимок для виджета: семь дней, московские минуты, флаги из настроек', () async {
    final c = await makeController(
      group: 'ПИ-25а',
      subgroup: 1,
      now: DateTime.utc(2026, 10, 29, 7),
      stored: {'preferences': '{"lockscreen":true,"reminders":true,"notificationMinutes":10}'},
    );
    final snapshot = widgetSnapshot(c.model.value, c.names, c.clock.value.today, c.store.prefs.value, c.store.selection.value, 1);
    expect(snapshot['group'], 'ПИ-25а · 1 п/г');
    expect(snapshot['live'], isTrue);
    expect(snapshot['persistent'], isFalse);
    expect(snapshot['remind'], 10);
    final days = snapshot['days'] as List;
    expect(days, hasLength(7));
    expect((days.last as Map)['date'], '2026-11-04');
    expect((days.first as Map)['date'], '2026-10-29');
    final lessons = (days.first as Map)['lessons'] as List;
    expect(lessons, isNotEmpty);
    final first = lessons.first as Map;
    expect(first['start'], lessThan(first['end'] as int));
    expect(first['kind'], isNotEmpty);
  });

  test('постоянное уведомление включается отдельно от экрана блокировки', () async {
    final c = await makeController(
      group: 'ПИ-25а',
      subgroup: 1,
      now: DateTime.utc(2026, 10, 29, 7),
      stored: {'preferences': '{"lockscreen":false,"persistent":true}'},
    );
    final snapshot = widgetSnapshot(c.model.value, c.names, c.clock.value.today, c.store.prefs.value, c.store.selection.value, 1);
    expect(snapshot['live'], isFalse);
    expect(snapshot['persistent'], isTrue);
    expect(const Prefs().lockscreen, isTrue);
    expect(const Prefs().persistent, isFalse);
  });

  test('без группы снимок пустой и не включает экран блокировки', () {
    final snapshot = widgetSnapshot(null, const {}, DateTime.utc(2026, 10, 29), const Prefs(), (group: '', subgroup: 0), 1);
    expect(snapshot['live'], isFalse);
    expect(snapshot['days'], isEmpty);
  });

  test('одинаковый снимок отправляется один раз, смена настроек отправляется снова', () async {
    final c = await makeController(group: 'ПИ-25а', subgroup: 1, now: DateTime.utc(2026, 10, 29, 7));
    final bridge = RecordingBridge();
    final sync = WidgetSync(c, bridge);
    await sync.publish();
    await sync.publish();
    expect(bridge.sent, hasLength(1));
    c.store.setPrefs((p) => p.copyWith(notificationMinutes: 5, reminders: true));
    await sync.publish();
    expect(bridge.sent, hasLength(2));
  });
}
