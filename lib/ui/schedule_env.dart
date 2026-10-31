import 'package:flutter/material.dart';

import '../data/schedule_model.dart';
import '../data/store.dart';

class ScheduleEnv {
  const ScheduleEnv({
    required this.model,
    required this.store,
    required this.clock,
    required this.selected,
    required this.headerHeight,
    required this.headerShift,
    required this.openLesson,
    required this.openCancelled,
    required this.openDay,
    required this.motion,
  });
  final ScheduleModel model;
  final AppStore store;
  final MskClock clock;
  final ValueNotifier<DateTime> selected;
  final ValueNotifier<double> headerHeight;
  final ValueNotifier<double> headerShift;
  final void Function(CardRow row) openLesson;
  final void Function(CancelledRow row) openCancelled;
  final void Function(DateTime day) openDay;
  final bool motion;
}

class ScrollReporter extends StatelessWidget {
  const ScrollReporter({super.key, required this.env, required this.child});
  final ScheduleEnv env;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.depth == 0 && n.metrics.axis == Axis.vertical) {
          final next = n.metrics.pixels.clamp(0.0, env.headerHeight.value);
          if (next != env.headerShift.value) env.headerShift.value = next;
        }
        return false;
      },
      child: child,
    );
  }
}
