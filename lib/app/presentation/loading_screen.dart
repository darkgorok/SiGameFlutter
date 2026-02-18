import 'dart:math' as math;

import 'package:flutter/material.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: const Center(child: LoadingPane()));
  }
}

class LoadingPane extends StatelessWidget {
  const LoadingPane({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [const LoadingDots(size: 14, gap: 8, jumpHeight: 12)],
    );
  }
}

class LoadingInline extends StatelessWidget {
  const LoadingInline({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LoadingDots(
        size: math.max(2.5, size * 0.18),
        gap: math.max(1.5, size * 0.1),
        jumpHeight: math.max(3.0, size * 0.35),
      ),
    );
  }
}

class LoadingDots extends StatefulWidget {
  const LoadingDots({
    super.key,
    this.count = 5,
    this.size = 8,
    this.gap = 5,
    this.jumpHeight = 6,
    this.duration = const Duration(milliseconds: 900),
  });

  final int count;
  final double size;
  final double gap;
  final double jumpHeight;
  final Duration duration;

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final dots = List<Widget>.generate(widget.count, (index) {
          final y = _dotOffset(index);
          return Transform.translate(
            offset: Offset(0, y),
            child: Container(
              width: widget.size,
              height: widget.size,
              margin: EdgeInsets.symmetric(horizontal: widget.gap / 2),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          );
        });
        return Row(mainAxisSize: MainAxisSize.min, children: dots);
      },
    );
  }

  double _dotOffset(int index) {
    final segment = 1 / widget.count;
    final shift = index * segment;
    var t = (_controller.value - shift) % 1;
    if (t < 0) {
      t += 1;
    }
    if (t >= segment) {
      return 0;
    }
    final p = t / segment;
    return -math.sin(p * math.pi) * widget.jumpHeight;
  }
}
