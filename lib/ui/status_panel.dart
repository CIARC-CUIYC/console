import 'dart:async';

import 'package:ciarc_console/main.dart';
import 'package:ciarc_console/service/ground_station_client.dart';
import 'package:flutter/material.dart';

import 'map_widget.dart';

class StatusPanel extends StatelessWidget {
  final Rect? highlightedArea;
  final GroundStationClient _groundStationClient = getIt.get();

  StatusPanel({super.key, this.highlightedArea});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: _groundStationClient.telemetry,
    builder: (context, telemetryRemoteData, widget_) {
      final telemetry = telemetryRemoteData?.data;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: MapWidget(
              highlightArea: highlightedArea,
              satellite: telemetry?.position,
              satelliteVelocity: telemetry?.velocity,
            ),
          ),
          Container(
            color: Theme.of(context).focusColor,
            padding: EdgeInsets.all(10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 5,
                      children: [
                        _infoLine(Icons.location_on, "Position", _formatOffset(telemetry?.position), "px"),
                        _infoLine(Icons.double_arrow, "Velocity", _formatOffset(telemetry?.velocity), "px/s"),
                        _infoLine(Icons.battery_5_bar, "Battery", telemetry?.battery.toString(), "%"),
                        _infoLine(Icons.local_gas_station, "Fuel", telemetry?.fuel.toString(), "%"),
                        if (telemetryRemoteData != null)
                          TimeAgo(
                            timestamp: telemetryRemoteData.timestamp,
                            builder: (context, timeString) => _infoLine(Icons.update, "Last Update", timeString, null),
                          ),
                      ],
                    ),
                  ),
                  VerticalDivider(width: 10),
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 5,
                      children: [
                        _infoLine(Icons.wifi, "Data volume", _formatDataVolume(telemetry?.dataVolume), null),
                        _infoLine(
                          Icons.directions,
                          "Distance covered",
                          telemetry?.distanceCovered.toStringAsFixed(1),
                          "px",
                        ),
                        _infoLine(Icons.check, "Objectives done", telemetry?.objectivesDone.toString(), null),
                        _infoLine(
                          Icons.leaderboard,
                          "Objectives points",
                          telemetry?.objectivesPoints.toString(),
                          "points",
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );

  static String? _formatOffset(Offset? offset) {
    if (offset == null) return null;
    return "${offset.dx}, ${offset.dy}";
  }

  static String? _formatDataVolume((int, int)? volume) {
    if (volume == null) return null;

    String formatSize(int size) {
      if (size < 1024) return "$size Kb";
      if (size < (1024 * 1024)) return "${(size / 1024).toStringAsFixed(2)} Mb";
      return "${(size / (1024 * 1024)).toStringAsFixed(2)} Gb";
    }

    return "Sent: ${formatSize(volume.$1)} - Recv: ${formatSize(volume.$2)}";
  }

  static Widget _infoLine(IconData icon, String label, String? value, String? unit) {
    String valueText;

    if (value == null) {
      valueText = "-";
    } else {
      valueText = value;
    }

    if (unit != null) {
      valueText += " $unit";
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 5,
      children: [Icon(icon), Expanded(child: Text(label)), Text(valueText)],
    );
  }
}

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

    if (duration < Duration(seconds: 15)) {
      nextTimerDuration = Duration(seconds: 15) - duration;
    } else if (duration < Duration(minutes: 1)) {
      nextTimerDuration = Duration(seconds: duration.inSeconds + 1) - duration;
    } else if (duration < Duration(minutes: 60)) {
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
    if (duration < Duration(seconds: 15)) return "just now";
    if (duration < Duration(minutes: 1)) return "${duration.inSeconds} s";
    if (duration < Duration(minutes: 60)) return "${duration.inMinutes} min";
    if (duration < Duration(hours: 24)) return "${duration.inHours}:${duration.inMinutes % 60} h";
    return "${duration.inDays},${(duration.inHours % 24) * (100.0 / 24.0)} days";
  }
}
