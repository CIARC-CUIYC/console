import 'common.dart';

abstract class Objective {
  final int? id;
  final String name;
  final String description;
  final DateTime start;
  final DateTime end;
  final double decreaseRate;

  Objective({
    required this.id,
    required this.name,
    required this.description,
    required this.start,
    required this.end,
    required this.decreaseRate,
  });

  @override
  String toString() {
    return "$id - $name - $description";
  }
}

class ZonedObjective extends Objective {
  final dynamic zone;
  final double coverageRequired;
  final CameraAngle opticRequired;
  final String? sprite;
  final bool secret;

  ZonedObjective({
    required super.id,
    required super.name,
    required super.description,
    required super.start,
    required super.end,
    required super.decreaseRate,
    required this.zone,
    required this.coverageRequired,
    required this.opticRequired,
    required this.sprite,
    required this.secret,
  });
}

class BeaconObjective extends Objective {
  final int attemptsMade;

  BeaconObjective({
    required super.id,
    required super.name,
    required super.description,
    required super.start,
    required super.end,
    required super.decreaseRate,
    required this.attemptsMade,
  });
}
