import 'dart:ui';

import 'common.dart';

sealed class Task {
  final DateTime scheduledOn;

  Task({required this.scheduledOn});
}

class TakeImageTask extends Task {
  final Offset plannedPosition;
  final Offset? actualPosition;

  TakeImageTask({required super.scheduledOn, required this.plannedPosition, required this.actualPosition});
}

class SwitchStateTask extends Task {
  final SatelliteState newState;

  SwitchStateTask({required super.scheduledOn, required this.newState});
}

class ChangeVelocityTask extends Task {
  final List<Offset> positions;

  ChangeVelocityTask({required super.scheduledOn, required this.positions});
}