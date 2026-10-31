import 'package:flutter/material.dart';

class Derived<T> extends StatefulWidget {
  const Derived({super.key, required this.listenable, required this.read, required this.builder});
  final Listenable listenable;
  final T Function() read;
  final Widget Function(BuildContext context, T value) builder;

  @override
  State<Derived<T>> createState() => _DerivedState<T>();
}

class _DerivedState<T> extends State<Derived<T>> {
  late T _value = widget.read();

  @override
  void initState() {
    super.initState();
    widget.listenable.addListener(_onChange);
  }

  @override
  void didUpdateWidget(Derived<T> old) {
    super.didUpdateWidget(old);
    if (old.listenable != widget.listenable) {
      old.listenable.removeListener(_onChange);
      widget.listenable.addListener(_onChange);
    }
    _value = widget.read();
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final next = widget.read();
    if (next != _value) setState(() => _value = next);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}

class Tap extends StatefulWidget {
  const Tap({super.key, required this.onTap, required this.child, this.label});
  final VoidCallback onTap;
  final Widget child;
  final String? label;

  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: widget.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _set(true),
          onTapUp: (_) => _set(false),
          onTapCancel: () => _set(false),
          onTap: widget.onTap,
          child: Opacity(opacity: _down ? 0.6 : 1, child: widget.child),
        ),
      );
}
