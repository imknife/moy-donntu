import 'package:flutter/material.dart';

import 'motion.dart';

class DaySwipe extends StatefulWidget {
  const DaySwipe({super.key, required this.onStep, required this.child, this.minHeight = 0});
  final void Function(int step) onStep;
  final Widget child;
  final double minHeight;

  @override
  State<DaySwipe> createState() => _DaySwipeState();
}

class _DaySwipeState extends State<DaySwipe> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  double _offset = 0;
  double _from = 0;
  double _to = 0;
  VoidCallback? _onSettled;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_tick);
    _controller.addStatusListener(_status);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _width = 360;

  void _tick() {
    final t = Curves.easeOutCubic.transform(_controller.value);
    setState(() => _offset = _from + (_to - _from) * t);
  }

  void _status(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final done = _onSettled;
    _onSettled = null;
    done?.call();
  }

  void _animate(double to, {VoidCallback? then}) {
    _from = _offset;
    _to = to;
    _onSettled = then;
    if (!context.motionEnabled) {
      setState(() => _offset = to);
      final done = _onSettled;
      _onSettled = null;
      done?.call();
      return;
    }
    _controller.forward(from: 0);
  }

  void _start(DragStartDetails details) {
    _controller.stop();
    _onSettled = null;
  }

  void _update(DragUpdateDetails details) {
    setState(() => _offset = (_offset + details.delta.dx).clamp(-_width, _width));
  }

  void _end(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final width = _width;
    final byDistance = _offset.abs() > width * 0.28;
    final byVelocity = velocity.abs() > 600 && (velocity < 0) == (_offset <= 0) && _offset.abs() > 8;
    final flickWithoutDrag = velocity.abs() > 600 && _offset.abs() <= 8;
    if (!byDistance && !byVelocity && !flickWithoutDrag) {
      _animate(0);
      return;
    }
    final step = byDistance ? (_offset < 0 ? 1 : -1) : (velocity < 0 ? 1 : -1);
    _animate(-step * width, then: () {
      widget.onStep(step);
      setState(() => _offset = step * width * 0.35);
      _animate(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth.isFinite && box.maxWidth > 0) _width = box.maxWidth;
        final progress = (_offset.abs() / _width).clamp(0.0, 1.0);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _start,
          onHorizontalDragUpdate: _update,
          onHorizontalDragEnd: _end,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: widget.minHeight > 0 ? widget.minHeight : MediaQuery.sizeOf(context).height * 0.6),
            child: Opacity(
              opacity: 1 - 0.55 * progress,
              child: Transform.translate(offset: Offset(_offset, 0), child: widget.child),
            ),
          ),
        );
      },
    );
  }
}
