import 'package:flutter/material.dart';

class MotionPolicy {
  static bool enabled = true;
}

class MotionScope extends InheritedWidget {
  const MotionScope({super.key, required this.enabled, required super.child});
  final bool enabled;

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<MotionScope>()?.enabled ?? true;

  @override
  bool updateShouldNotify(MotionScope old) => old.enabled != enabled;
}

extension MotionContext on BuildContext {
  bool get motionEnabled => MotionScope.of(this);
}

class QuietRoute<T> extends PageRoute<T> {
  QuietRoute({required this.builder, super.settings});
  final WidgetBuilder builder;

  @override
  Duration get transitionDuration => MotionPolicy.enabled ? const Duration(milliseconds: 200) : Duration.zero;

  @override
  Duration get reverseTransitionDuration => MotionPolicy.enabled ? const Duration(milliseconds: 160) : Duration.zero;

  @override
  bool get opaque => true;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) => builder(context);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (!MotionPolicy.enabled) return child;
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(curved), child: child),
    );
  }
}

Route<T> quietRoute<T>(BuildContext context, WidgetBuilder builder) => QuietRoute<T>(builder: builder);
