import 'dart:async';
import 'dart:convert';

import '../domain/schedule.dart';
import '../domain/time_utils.dart';
import 'app_controller.dart';
import 'config.dart';
import 'native_bridge.dart';
import 'schedule_model.dart';
import 'store.dart';

const widgetDays = 7;

Map<String, dynamic> widgetSnapshot(ScheduleModel? model, Map<String, String> names, DateTime today, Prefs prefs, Selection selection, int nowMillis, {String? apiUrl}) {
  if (model == null) {
    return {'group': 'Выберите группу', 'updatedAt': nowMillis, 'live': false, 'remind': 0, 'days': <Object>[]};
  }
  final days = [
    for (var i = 0; i < widgetDays; i++)
      () {
        final date = addDays(today, i);
        return {
          'date': ymd(date),
          'lessons': [
            for (final it in model.items(date))
              {
                'start': it.bell.startMinutes,
                'end': it.bell.endMinutes,
                'subject': it.lesson.subject,
                'kind': kindLabel[it.lesson.kind] ?? '',
                'rooms': roomsLabel(it.lesson),
                'teacher': teachersLabel(it.lesson, names),
                'change': it.change,
              },
          ],
        };
      }(),
  ];
  final sub = selection.subgroup;
  return {
    'group': '${model.pkg.code}${sub > 0 ? ' · $sub п/г' : ''}',
    'updatedAt': nowMillis,
    'live': prefs.lockscreen,
    'persistent': prefs.persistent,
    'remind': prefs.reminders ? prefs.notificationMinutes : 0,
    'changeAlerts': prefs.changeAlerts,
    'groupCode': model.pkg.code,
    'seen': model.pkg.version,
    'apiUrl': apiUrl ?? '',
    'days': days,
  };
}

String snapshotFingerprint(Map<String, dynamic> snapshot) => jsonEncode(Map<String, dynamic>.of(snapshot)..remove('updatedAt'));

class WidgetSync {
  WidgetSync(this._app, this._bridge);
  final AppController _app;
  final NativeBridge _bridge;
  String _last = '';
  Future<void> _queue = Future.value();
  Timer? _debounce;

  void start() {
    if (!_bridge.available) return;
    _app.model.addListener(schedule);
    _app.store.prefs.addListener(schedule);
    _app.store.selection.addListener(schedule);
    _app.clock.addListener(schedule);
    schedule();
  }

  void stop() {
    _debounce?.cancel();
    _app.model.removeListener(schedule);
    _app.store.prefs.removeListener(schedule);
    _app.store.selection.removeListener(schedule);
    _app.clock.removeListener(schedule);
  }

  void schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => unawaited(publish()));
  }

  Future<void> publish() {
    final snapshot = widgetSnapshot(_app.model.value, _app.names, _app.clock.value.today, _app.store.prefs.value, _app.store.selection.value, DateTime.now().millisecondsSinceEpoch, apiUrl: AppConfig.apiUrl);
    final fingerprint = snapshotFingerprint(snapshot);
    final json = jsonEncode(snapshot);
    _queue = _queue.catchError((Object _) {}).then((_) async {
      if (fingerprint == _last) return;
      if (await _bridge.sync(json)) _last = fingerprint;
    });
    return _queue;
  }
}
