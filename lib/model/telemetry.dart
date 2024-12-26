import 'dart:ui';

import 'common.dart';

class Telemetry {
  final SatelliteState state;
  final Offset position;
  final Offset velocity;
  final double battery;
  final double fuel;
  final (int sent, int received) dataVolume;
  final double distanceCovered;
  final int objectivesDone;
  final int objectivesPoints;

  Telemetry({
    required this.state,
    required this.position,
    required this.velocity,
    required this.battery,
    required this.fuel,
    required this.dataVolume,
    required this.distanceCovered,
    required this.objectivesDone,
    required this.objectivesPoints,
  });
}
