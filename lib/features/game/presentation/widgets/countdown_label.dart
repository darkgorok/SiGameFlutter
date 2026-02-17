import 'dart:async';

import 'package:flutter/material.dart';

class CountdownLabel extends StatefulWidget {
  const CountdownLabel({super.key, required this.deadlineMs, this.onExpired});

  final int deadlineMs;
  final VoidCallback? onExpired;

  @override
  State<CountdownLabel> createState() => _CountdownLabelState();
}

class _CountdownLabelState extends State<CountdownLabel> {
  late Timer _timer;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        final left = widget.deadlineMs - DateTime.now().millisecondsSinceEpoch;
        if (left <= 0 && !_fired) {
          _fired = true;
          widget.onExpired?.call();
        }
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant CountdownLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadlineMs != widget.deadlineMs) {
      _fired = false;
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left =
        ((widget.deadlineMs - DateTime.now().millisecondsSinceEpoch) / 1000)
            .ceil();
    final safe = left < 0 ? 0 : left;
    return Text('Таймер: $safe сек');
  }
}
