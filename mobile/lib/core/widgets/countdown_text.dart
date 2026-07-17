import 'dart:async';
import 'package:flutter/material.dart';

class CountdownText extends StatefulWidget {
  final DateTime targetTime;
  final TextStyle? style;
  final Color? closedColor;
  final String closedText;

  const CountdownText({
    super.key,
    required this.targetTime,
    this.style,
    this.closedColor = Colors.orangeAccent,
    this.closedText = 'CLOSED / DRAWING',
  });

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.targetTime.difference(DateTime.now());
    _startTimer();
  }

  @override
  void didUpdateWidget(CountdownText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetTime != widget.targetTime) {
      _remaining = widget.targetTime.difference(DateTime.now());
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_remaining.isNegative) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final newRemaining = widget.targetTime.difference(DateTime.now());
      setState(() {
        _remaining = newRemaining;
      });
      if (newRemaining.isNegative) {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return widget.closedText;
    final int days = d.inDays;
    final int hours = d.inHours.remainder(24);
    final int minutes = d.inMinutes.remainder(60);
    final int seconds = d.inSeconds.remainder(60);

    if (days > 0) {
      return "$days days, ${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m";
    }

    final String hs = (d.inHours).toString().padLeft(2, '0');
    final String ms = minutes.toString().padLeft(2, '0');
    final String ss = seconds.toString().padLeft(2, '0');

    return '$hs:$ms:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final isClosed = _remaining.isNegative;
    return Text(
      _formatDuration(_remaining),
      style: (widget.style ?? const TextStyle()).copyWith(
        color: isClosed ? widget.closedColor : (widget.style?.color ?? Colors.white),
      ),
    );
  }
}
