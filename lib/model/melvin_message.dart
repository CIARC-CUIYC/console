abstract class UpstreamMessage {
  final DateTime timestamp;

  bool checkIfObsoletes(UpstreamMessage other);

  Map serialize();

  int? ttl;

  UpstreamMessage({DateTime? timestamp, this.ttl}) : timestamp = timestamp ?? DateTime.timestamp();
}

class GetCurrentTelemetryMessage extends UpstreamMessage {
  @override
  bool checkIfObsoletes(UpstreamMessage other) => other is GetCurrentTelemetryMessage;

  @override
  Map serialize() => {"type": "GT"};
}

enum CameraAngle { narrow, normal, wide }

enum State { deployment, safe, communication, charge, acquisition, transition, none }

class ControlMessage extends UpstreamMessage {
  final (double x, double y)? velocity;
  final State? state;
  final CameraAngle? cameraAngle;

  ControlMessage({super.timestamp, super.ttl, required this.velocity, required this.state, required this.cameraAngle});

  @override
  bool checkIfObsoletes(UpstreamMessage other) => other is ControlMessage;

  @override
  Map serialize() => {"type": "C"};
}

class TakeImageImmediateMessage extends UpstreamMessage {
  @override
  bool checkIfObsoletes(UpstreamMessage other) => other is TakeImageImmediateMessage;

  @override
  Map serialize() => {};

}

class TakeImageAtPositionMessage extends UpstreamMessage {
  @override
  bool checkIfObsoletes(UpstreamMessage other) => other is TakeImageImmediateMessage;

  @override
  Map serialize() => {};
}


class GetImageAreaMessage extends UpstreamMessage {
  @override
  bool checkIfObsoletes(UpstreamMessage other) => other is TakeImageImmediateMessage;

  @override
  Map serialize() => {};
}


class SubscribeImageUpdatesMessage extends UpstreamMessage {
  @override
  bool checkIfObsoletes(UpstreamMessage other) => other is TakeImageImmediateMessage;

  @override
  Map serialize() => {};
}
