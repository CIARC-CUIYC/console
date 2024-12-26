import 'dart:async';

import 'package:flutter/widgets.dart';

class TimeAgo extends StatefulWidget {
  final DateTime timestamp;
  final Function(BuildContext context, String durationText) builder;

  const TimeAgo({super.key, required this.timestamp, required this.builder});

  @override
  State<StatefulWidget> createState() => _TimeAgoState();
}

class _TimeAgoState extends State<TimeAgo> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _setTimer();
  }

  @override
  void didUpdateWidget(covariant TimeAgo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timestamp != widget.timestamp) {
      _timer?.cancel();
      _setTimer();
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _formatTimeAgo(widget.timestamp));

  void _setTimer() {
    final Duration nextTimerDuration;
    final duration = DateTime.timestamp().difference(widget.timestamp);

    if (duration < const Duration(seconds: 15)) {
      nextTimerDuration = Duration(seconds: 15) - duration;
    } else if (duration < const Duration(minutes: 1)) {
      nextTimerDuration = Duration(seconds: duration.inSeconds + 1) - duration;
    } else if (duration < const Duration(hours: 24)) {
      nextTimerDuration = Duration(minutes: duration.inMinutes + 1) - duration;
    } else {
      nextTimerDuration = Duration(hours: duration.inHours + 1) - duration;
    }
    _timer = Timer(nextTimerDuration, () {
      setState(() {});
      _setTimer();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static String _formatTimeAgo(DateTime timestamp) {
    final duration = DateTime.timestamp().difference(timestamp);
    if (duration < const Duration(seconds: 15)) return "just now";
    if (duration < const Duration(minutes: 1)) return "${duration.inSeconds} s";
    if (duration < const Duration(minutes: 60)) return "${duration.inMinutes} min";
    if (duration < const Duration(hours: 24)) return "${duration.inHours}:${duration.inMinutes % 60} h";
    return "${duration.inDays},${(duration.inHours % 24) * (100.0 / 24.0)} days";
  }
}
