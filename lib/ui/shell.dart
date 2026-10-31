import 'package:flutter/material.dart';

import '../data/app_controller.dart';
import 'derived.dart';
import 'icons.dart';
import 'motion.dart';
import 'overview.dart';
import 'profile.dart';
import 'schedule_screen.dart';
import 'services.dart';
import 'theme.dart';

const _tabIcons = ['home', 'schedule', 'services', 'profile'];
const _tabLabels = ['Обзор', 'Расписание', 'Сервисы', 'Профиль'];
const _tabOrder = [0, 1, 2, 3];

int tabForStart(String start) => switch (start) {
      'overview' => 0,
      'services' || 'search' => 2,
      'profile' => 3,
      _ => 1,
    };

class Shell extends StatelessWidget {
  const Shell({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Scaffold(
      backgroundColor: c.background,
      body: Derived<int>(
        listenable: controller.tab,
        read: () => controller.tab.value,
        builder: (context, tab) => IndexedStack(
          index: tab,
          children: [
            const OverviewTab(),
            ScheduleScreen(controller: controller),
            const ServicesTab(),
            const ProfileTab(),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(tab: controller.tab),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.tab});
  final ValueNotifier<int> tab;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final duration = context.motionEnabled ? const Duration(milliseconds: 220) : Duration.zero;
    return Container(
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.hairline))),
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: Derived<int>(
        listenable: tab,
        read: () => tab.value,
        builder: (context, current) => Stack(
          children: [
            Positioned.fill(
              child: AnimatedAlign(
                duration: duration,
                curve: Curves.easeOutCubic,
                alignment: Alignment(-1 + 2 * current / (_tabOrder.length - 1), -1),
                child: FractionallySizedBox(
                  widthFactor: 1 / _tabOrder.length,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Align(alignment: Alignment.topCenter, child: Container(width: 52, height: 30, decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(15)))),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (final i in _tabOrder)
                  Expanded(
                    child: Tap(
                      label: _tabLabels[i],
                      onTap: () => tab.value = i,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 30,
                              child: Center(
                                child: AnimatedScale(
                                  duration: duration,
                                  curve: Curves.easeOutBack,
                                  scale: i == current ? 1.08 : 1,
                                  child: TweenAnimationBuilder<Color?>(
                                    duration: duration,
                                    tween: ColorTween(end: i == current ? c.text : c.muted),
                                    builder: (context, color, _) => AppIcon(_tabIcons[i], size: 22, color: color ?? c.muted),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            ExcludeSemantics(
                              child: AnimatedDefaultTextStyle(
                                duration: duration,
                                style: T.dayName.copyWith(fontWeight: i == current ? FontWeight.w600 : FontWeight.w500, height: 14 / 11, color: i == current ? c.text : c.muted),
                                child: Text(_tabLabels[i], maxLines: 1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
