import 'package:ciarc_console/model/telemetry.dart';
import 'package:flutter/material.dart';

import 'map_widget.dart';

class StatusPanel extends StatelessWidget {
  final Rect? highlightedArea;
  final Telemetry? telemetry;

  const StatusPanel({super.key, this.telemetry, this.highlightedArea});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
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
              crossAxisAlignment: CrossAxisAlignment.center,
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
                      _infoLine(Icons.location_on, "Position", telemetry?.position.toString(), "px"),
                      _infoLine(Icons.double_arrow, "Velocity", telemetry?.velocity.toString(), "px/s"),
                      _infoLine(Icons.battery_5_bar, "Battery", telemetry?.battery.toString(), "%"),
                      _infoLine(Icons.local_gas_station, "Fuel", telemetry?.fuel.toString(), "%"),
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
                      _infoLine(Icons.wifi, "Data volume", telemetry?.dataVolume.toString(), "kb"),
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
  }

  Widget _infoLine(IconData icon, String label, String? value, String? unit) {
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
