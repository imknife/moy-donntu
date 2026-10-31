import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

class NativeStatus {
  const NativeStatus({
    this.notifications = true,
    this.exactAlarms = true,
    this.promoted = true,
    this.stoppedToday = false,
    this.manufacturer = '',
  });
  final bool notifications;
  final bool exactAlarms;
  final bool promoted;
  final bool stoppedToday;
  final String manufacturer;

  bool get vivo => manufacturer.contains('vivo') || manufacturer.contains('iqoo');

  factory NativeStatus.fromJson(Map<String, dynamic> j) => NativeStatus(
        notifications: j['notifications'] as bool? ?? true,
        exactAlarms: j['exactAlarms'] as bool? ?? true,
        promoted: j['promoted'] as bool? ?? true,
        stoppedToday: j['stoppedToday'] as bool? ?? false,
        manufacturer: j['manufacturer'] as String? ?? '',
      );
}

abstract class NativeBridge {
  bool get available;
  Future<bool> sync(String snapshot);
  Future<void> resume();
  Future<NativeStatus> status();
  Future<void> requestNotifications();
  Future<bool> openSettings(String target);
  Future<bool> scheduleManual(int id, int at, String title, String body);
  Future<void> cancelManual(int id);
  Future<bool> openCalendarFile(String path);
}

class MethodChannelBridge implements NativeBridge {
  static const _channel = MethodChannel('ru.donntu.schedule/native');

  @override
  bool get available => Platform.isAndroid;

  Future<T?> _call<T>(String method, [Object? arguments]) async {
    if (!available) return null;
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<bool> sync(String snapshot) async => await _call<bool>('sync', snapshot) ?? false;

  @override
  Future<void> resume() async => _call<bool>('resume');

  @override
  Future<NativeStatus> status() async {
    final raw = await _call<String>('status');
    if (raw == null) return const NativeStatus();
    return NativeStatus.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> requestNotifications() async => _call<bool>('requestNotifications');

  @override
  Future<bool> openSettings(String target) async => await _call<bool>('openSettings', target) ?? false;

  @override
  Future<bool> scheduleManual(int id, int at, String title, String body) async => await _call<bool>('scheduleManual', {'id': id, 'at': at, 'title': title, 'body': body}) ?? false;

  @override
  Future<void> cancelManual(int id) async => _call<bool>('cancelManual', id);

  @override
  Future<bool> openCalendarFile(String path) async => await _call<bool>('openCalendar', path) ?? false;
}

class NoNativeBridge implements NativeBridge {
  const NoNativeBridge();

  @override
  bool get available => false;

  @override
  Future<bool> sync(String snapshot) async => false;

  @override
  Future<void> resume() async {}

  @override
  Future<NativeStatus> status() async => const NativeStatus();

  @override
  Future<void> requestNotifications() async {}

  @override
  Future<bool> openSettings(String target) async => false;

  @override
  Future<bool> scheduleManual(int id, int at, String title, String body) async => false;

  @override
  Future<void> cancelManual(int id) async {}

  @override
  Future<bool> openCalendarFile(String path) async => false;
}
