import 'package:flutter/material.dart';

import '../data/app_controller.dart';
import 'derived.dart';
import 'schedule_picker.dart';
import 'theme.dart';
import 'type_settings.dart';
import 'widgets.dart';

class FirstRunPage extends StatelessWidget {
  const FirstRunPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            const ScreenTitle('Выберите группу'),
            const SizedBox(height: 8),
            Expanded(child: SchedulePickerBody(controller: controller, onChosen: () => controller.store.setPrefs((p) => p.copyWith(onboarded: true)))),
            Tap(
              label: 'Войти через кабинет',
              onTap: () => Navigator.of(context).pushNamed('/login'),
              child: SizedBox(height: 52, child: Center(child: Text('Войти через кабинет'.cased, style: T.subject.copyWith(color: c.link)))),
            ),
          ],
        ),
      ),
    );
  }
}
