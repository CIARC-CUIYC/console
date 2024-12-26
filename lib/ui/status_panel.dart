import 'package:flutter/material.dart';

import '../main.dart';
import '../service/ground_station_client.dart';
import 'map_widget.dart';
import 'time_ago.dart';

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