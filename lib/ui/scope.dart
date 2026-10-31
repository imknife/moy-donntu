import 'package:flutter/material.dart';

import '../data/app_controller.dart';

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.controller, required super.child});
  final AppController controller;

  static AppController of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.controller;

  @override
  bool updateShouldNotify(AppScope old) => old.controller != controller;
}

String pageLocation(String page, [Map<String, String> params = const {}]) => Uri(path: '/$page', queryParameters: params.isEmpty ? null : params).toString();

extension AppContext on BuildContext {
  AppController get app => AppScope.of(this);

  Future<T?> open<T extends Object?>(String page, [Map<String, String> params = const {}]) => Navigator.of(this).pushNamed<T>(pageLocation(page, params));

  void openTab(int tab) {
    Navigator.of(this).popUntil((route) => route.isFirst);
    app.tab.value = tab;
  }
}
