import 'package:ciarc_console/model/common.dart';
import 'package:ciarc_console/model/telemetry.dart';
import 'package:ciarc_console/service/melvin_client.dart';
import 'package:flutter/material.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../main.dart';
import '../service/ground_station_client.dart';
import 'map_widget.dart';
import 'time_ago.dart';

class StatusPanel extends StatelessWidget {
  final Rect? highlightedArea;
  final bool compact;
  final GroundStationClient _groundStationClient = getIt.get();
  final MelvinClient _melvinClient = getIt.get();

  StatusPanel({super.key, this.highlightedArea, required this.compact});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_groundStationClient.telemetry, _melvinClient.mapImage, _melvinClient.telemetry]),
    builder: (context, widget_) {
      RemoteData<Telemetry>? telemetry;
      if (_melvinClient.telemetry.value != null &&
          _groundStationClient.telemetry.value?.timestamp.isAfter(_melvinClient.telemetry.value!.timestamp) != true) {
        telemetry = _melvinClient.telemetry.value;
      } else {
        telemetry = _groundStationClient.telemetry.value;
      }
      if (compact) {
        return SlidingUpPanel(
          body: _buildMap(telemetry),
          isDraggable: true,
          padding: EdgeInsets.zero,
          maxHeight: 300,
          panel: _buildInfoPanel(context, telemetry),
        );
      } else {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [Expanded(flex: 3, child: _buildMap(telemetry)), _buildInfoPanel(context, telemetry)],
        );
      }
    },
  );

  Widget _buildMap(RemoteData<Telemetry>? telemetry) => MapWidget(
    mapImage: _melvinClient.mapImage.value,
    highlightArea: highlightedArea,
    satellite: telemetry?.data.position,
    satelliteVelocity: telemetry?.data.velocity,
  );

  Widget _buildInfoPanel(BuildContext context, RemoteData<Telemetry>? telemetry) {
    final leftInfos = [
      _infoLine(Icons.location_on, "Position", _formatOffset(telemetry?.data.position), "px"),
      _infoLine(Icons.double_arrow, "Velocity", _formatOffset(telemetry?.data.velocity), "px/s"),
      _infoLine(Icons.battery_5_bar, "Battery", telemetry?.data.battery.toString(), "%"),
      _infoLine(Icons.local_gas_station, "Fuel", telemetry?.data.fuel.toString(), "%"),
      _infoLine(Icons.commit, "State", telemetry?.data.state.name, null),
    ];

    final rightInfos = [
      _infoLine(Icons.wifi, "Data volume", _formatDataVolume(telemetry?.data.dataVolume), null),
      _infoLine(Icons.directions, "Distance covered", telemetry?.data.distanceCovered.toStringAsFixed(1), "px"),
      if (telemetry != null)
        TimeAgo(
          timestamp: telemetry.timestamp,
          builder: (context, timeString) => _infoLine(Icons.update, "Last Update", timeString, null),
        ),
      _infoLine(
        Icons.check,
        "Objectives done",
        _groundStationClient.telemetry.value?.data.objectivesDone.toString(),
        null,
      ),
      _infoLine(
        Icons.leaderboard,
        "Objectives points",
        _groundStationClient.telemetry.value?.data.objectivesPoints.toString(),
        "points",
      ),
    ];

    final Widget panel;
    if (compact) {
      panel = Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 5,
        children: [...leftInfos, ...rightInfos],
      );
    } else {
      panel = IntrinsicHeight(
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
                children: leftInfos,
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
                children: rightInfos,
              ),
            ),
          ],
        ),
      );
    }
    return Container(padding: EdgeInsets.all(5), color: Theme.of(context).focusColor, child: panel);
  }

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
