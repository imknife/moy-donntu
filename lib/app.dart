import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/app_controller.dart';
import 'data/store.dart';
import 'data/widget_sync.dart';
import 'ui/motion.dart';
import 'ui/first_run.dart';
import 'ui/routes.dart';
import 'ui/scope.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';
import 'ui/type_settings.dart';

class App extends StatefulWidget {
  const App({super.key, required this.controller});
  final AppController controller;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  AppController get _c => widget.controller;
  late final WidgetSync _widgetSync = WidgetSync(_c, _c.native);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _c.tab.value = tabForStart(_c.store.prefs.value.startScreen);
    _c.startClock();
    unawaited(_c.start());
    _widgetSync.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetSync.stop();
    _c.stopClock();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _c.clock.tick();
      if (_c.store.prefs.value.autoSync) unawaited(_c.refreshAll());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Prefs>(
      valueListenable: _c.store.prefs,
      builder: (context, prefs, _) {
        final platformDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
        final dark = switch (prefs.theme) {
          ThemeChoice.dark => true,
          ThemeChoice.light => false,
          ThemeChoice.system => platformDark,
        };
        final pal = dark ? Pal.darkPal : Pal.light;
        final motion = !MediaQuery.disableAnimationsOf(context);
        MotionPolicy.enabled = motion;
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: pal.surface,
          systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        ));
        return AppScope(
          controller: _c,
          child: PalScope(
            pal: pal,
            child: MotionScope(
              enabled: motion,
              child: MaterialApp(
                title: 'Расписание пар',
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                  useMaterial3: true,
                  brightness: dark ? Brightness.dark : Brightness.light,
                  fontFamily: TypeSettings.family,
                  scaffoldBackgroundColor: pal.background,
                  splashFactory: NoSplash.splashFactory,
                ),
                builder: (context, child) {
                  final mq = MediaQuery.of(context);
                  final scaler = prefs.largeText ? TextScaler.linear(mq.textScaler.scale(1) * 1.18) : mq.textScaler;
                  return MediaQuery(data: mq.copyWith(textScaler: scaler), child: child!);
                },
                onGenerateRoute: (settings) => generateAppRoute(settings, _c),
                home: ValueListenableBuilder(
                  valueListenable: _c.model,
                  builder: (context, model, _) => prefs.onboarded && (model != null || prefs.activeTeacher.isNotEmpty) ? Shell(controller: _c) : FirstRunPage(controller: _c),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
