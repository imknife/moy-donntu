import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion.dart';
import 'theme.dart';

enum HighlightStyle { straight, wavy, brush }

const _markPeriod = Duration(milliseconds: 380);

Color highlightFill(Pal pal, HighlightStyle style) {
  final base = pal.dark ? 0.34 : 0.30;
  final extra = style == HighlightStyle.brush ? 0.10 : 0.0;
  return pal.link.withValues(alpha: base + extra);
}

class HighlightScope extends InheritedWidget {
  const HighlightScope({super.key, required this.style, required super.child});
  final HighlightStyle style;

  static HighlightStyle of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<HighlightScope>()?.style ?? HighlightStyle.straight;

  @override
  bool updateShouldNotify(HighlightScope old) => old.style != style;
}

class HighlightMark extends StatefulWidget {
  const HighlightMark({
    super.key,
    required this.child,
    this.style,
    this.color,
    this.animate = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 3),
  });
  final Widget child;
  final HighlightStyle? style;
  final Color? color;
  final bool animate;
  final EdgeInsetsGeometry padding;

  @override
  State<HighlightMark> createState() => _HighlightMarkState();
}

class _HighlightMarkState extends State<HighlightMark> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: _markPeriod);
  late final Animation<double> _progress = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.animate && context.motionEnabled) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? HighlightScope.of(context);
    final fill = widget.color ?? highlightFill(context.pal, style);
    final mark = RepaintBoundary(child: CustomPaint(painter: _MarkPainter(style: style, color: fill)));
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: AnimatedBuilder(
              animation: _progress,
              child: mark,
              builder: (context, child) {
                final t = _progress.value;
                if (t >= 1) return child!;
                return Opacity(
                  opacity: t,
                  child: Transform(alignment: Alignment.centerLeft, transform: Matrix4.diagonal3Values(0.45 + 0.55 * t, 1, 1), child: child),
                );
              },
            ),
          ),
        ),
        Padding(padding: widget.padding, child: widget.child),
      ],
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.style, required this.color});
  final HighlightStyle style;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final path = switch (style) {
      HighlightStyle.straight => _straight(size),
      HighlightStyle.wavy => _wavy(size),
      HighlightStyle.brush => _brush(size),
    };
    canvas.drawPath(path, Paint()..color = color..isAntiAlias = true);
  }

  Path _straight(Size s) {
    final w = s.width, h = s.height;
    final top = h * 0.30, bottom = h * 0.86, mid = (top + bottom) / 2;
    return Path()
      ..moveTo(-1.5, top + 1.5)
      ..quadraticBezierTo(w * 0.5, top - 1.2, w + 2.5, top)
      ..quadraticBezierTo(w + 5, mid - 1, w + 2, bottom - 1)
      ..quadraticBezierTo(w * 0.5, bottom + 1.4, -2.5, bottom)
      ..quadraticBezierTo(-5, mid + 1, -1.5, top + 1.5)
      ..close();
  }

  Path _wavy(Size s) {
    final w = s.width, h = s.height;
    final top = h * 0.32, bottom = h * 0.84;
    final amplitude = math.max(1.2, h * 0.07);
    final period = math.max(18.0, h * 1.3);
    final from = -2.5, to = w + 3.0;
    final xs = <double>[];
    for (var x = from; x < to; x += 3) {
      xs.add(x);
    }
    xs.add(to);
    double upper(double x) => top + amplitude * math.sin(x / period * 2 * math.pi);
    double lower(double x) => bottom + amplitude * math.sin(x / period * 2 * math.pi + 1.1);
    final path = Path()..moveTo(xs.first, upper(xs.first));
    for (final x in xs.skip(1)) {
      path.lineTo(x, upper(x));
    }
    for (final x in xs.reversed) {
      path.lineTo(x, lower(x));
    }
    return path..close();
  }

  Path _brush(Size s) {
    final w = s.width, h = s.height;
    final thickness = h * 0.34;
    final leftY = h * 0.82, rightY = h * 0.75;
    return Path()
      ..moveTo(-3, leftY)
      ..cubicTo(w * 0.22, leftY - thickness * 0.95, w * 0.68, rightY - thickness * 1.1, w + 4, rightY - 0.5)
      ..cubicTo(w * 0.72, rightY + thickness * 0.45, w * 0.3, leftY + thickness * 0.6, -3, leftY)
      ..close();
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.style != style || old.color != color;
}
