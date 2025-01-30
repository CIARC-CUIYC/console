import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:ciarc_console/model/task.dart';
import 'package:ciarc_console/model/telemetry.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';

import '../model/common.dart';
import '../model/melvin_messages.pb.dart' as proto;
import '../ui/map_widget.dart';

enum MelvinConnectionState { notConnected, connectedToMachine, connectedToMachineAndMelvin }

@singleton
class MelvinClient {
  final MelvinProtocolClient _protocolClient = SSHMelvinProtocolClient();
  //final MelvinProtocolClient _protocolClient = LocalMelvinProtocolClient();
  Timer? _retryTimer;
  StreamSubscription<proto.Downstream>? _downstreamSubscription;
  ValueNotifier<ui.Image?> mapImage = ValueNotifier(null);
  ValueNotifier<RemoteData<Telemetry>?> telemetry = ValueNotifier(null);
  ValueNotifier<RemoteData<List<Task>>?> tasks = ValueNotifier(null);
  ValueNotifier<MelvinConnectionState> connectionState = ValueNotifier(MelvinConnectionState.notConnected);
  bool _closed = false;
  int lastSnapshot = 0;
  bool _paused = false;
  bool _tryingConnect = false;
  Completer<int?>? _pendingSubmit;
  Timer? _pendingSubmitTimeout;

  MelvinClient() {
    _tryConnect();
  }

  Future<void> _tryConnect() async {
    final newConnectionState = await _protocolClient.tryConnect();
    if (newConnectionState == MelvinConnectionState.connectedToMachineAndMelvin) {
      _tryingConnect = false;
      connectionState.value = newConnectionState;
      _retryTimer = null;
      _downstreamSubscription = _protocolClient.downstream.listen(_onDownstreamMessage, onDone: _restart);
      await _fetchMapImage();
    } else {
      connectionState.value = newConnectionState;
      if (_paused) {
        _tryingConnect = false;
      } else {
        _retryTimer = Timer(Duration(seconds: 5), _tryConnect);
      }
    }
  }

  void _restart() {
    if (_tryingConnect) return;
    _tryingConnect = true;
    connectionState.value = MelvinConnectionState.notConnected;
    _pendingSubmitTimeout?.cancel();
    final pendingSubmit = _pendingSubmit;
    _pendingSubmit = null;
    pendingSubmit?.completeError(Exception("connection closed"));
    if (!_closed) {
      _downstreamSubscription?.cancel();
      _downstreamSubscription = null;
      _tryConnect();
    }
  }

  void pause() {
    //_paused = true;
    //_retryTimer?.cancel();
    //_retryTimer = null;
  }

  void resume() {
    //if (!_paused) return;
    //_paused = false;
    //if (connectionState.value != MelvinConnectionState.connectedToMachine) {
    //  _restart();
    //}
  }

  Future<void> _fetchMapImage() async {
    if (mapImage.value == null) {
      await _protocolClient.send(proto.Upstream(getFullImage: proto.Upstream_GetFullImage()));
    } else {
      await _protocolClient.send(proto.Upstream(getSnapshotImage: proto.Upstream_GetSnapshotDiffImage()));
    }
  }

  Future<void> submitObjective(int objectiveId, Rect area) async {
    if (_pendingSubmit != null) throw Exception("Concurrent submit");
    _pendingSubmit = Completer();
    _pendingSubmitTimeout = Timer(Duration(seconds: 10), () {
      final pendingSubmit = _pendingSubmit;
      _pendingSubmit = null;
      if (pendingSubmit != null && !pendingSubmit.isCompleted) {
        pendingSubmit.completeError(TimeoutException("timeout"));
      }
    });

    await _protocolClient.send(
      proto.Upstream(
        submitObjective: proto.Upstream_SubmitObjective(
          objectiveId: objectiveId,
          offsetX: area.topLeft.dx.toInt(),
          offsetY: area.topLeft.dy.toInt(),
          width: area.width.toInt(),
          height: area.height.toInt(),
        ),
      ),
    );

    final objectiveIdFromResult = await _pendingSubmit!.future;
    if (objectiveIdFromResult != objectiveId) {
      throw Exception("Mismatching objective ids");
    }
  }

  void _onDownstreamMessage(proto.Downstream downstreamMessage) {
    if (downstreamMessage.hasImage()) {
      final imageMessage = downstreamMessage.image;
      final oldImage = mapImage.value;
      _composeImage(
        imageMessage.offsetX,
        imageMessage.offsetY,
        Uint8List.fromList(imageMessage.data),
        oldImage,
      ).then((newImage) => mapImage.value = newImage);
      lastSnapshot++;
      if (lastSnapshot >= 2) {
        //_protocolClient?.send(proto.Upstream(createSnapshotImage: proto.Upstream_CreateSnapshotImage()));
        lastSnapshot = 0;
      }
    } else if (downstreamMessage.hasTelemetry()) {
      final telemetryMessage = downstreamMessage.telemetry;

      telemetry.value = RemoteData(
        timestamp: DateTime.fromMillisecondsSinceEpoch(telemetryMessage.timestamp.toInt()),
        data: Telemetry(
          state: _mapState(telemetryMessage.state),
          position: Offset(telemetryMessage.positionX.toDouble(), telemetryMessage.positionY.toDouble()),
          velocity: Offset(telemetryMessage.velocityX.toDouble(), telemetryMessage.velocityY.toDouble()),
          battery: telemetryMessage.battery,
          fuel: telemetryMessage.fuel,
          dataVolume: (telemetryMessage.dataSent, telemetryMessage.dataReceived),
          distanceCovered: telemetryMessage.distanceCovered,
          objectivesDone: 0,
          objectivesPoints: 0,
        ),
      );
    } else if (downstreamMessage.hasSubmitResult()) {
      _pendingSubmitTimeout?.cancel();
      final pendingSubmit = _pendingSubmit;
      _pendingSubmit = null;
      if (pendingSubmit != null && !pendingSubmit.isCompleted) {
        final submitResult = downstreamMessage.submitResult;
        if (submitResult.success) {
          pendingSubmit.complete(submitResult.hasObjectiveId() ? submitResult.objectiveId : null);
        } else {
          pendingSubmit.completeError(Exception("Submit failed"));
        }
      }
    } else if (downstreamMessage.hasTaskList()) {
      final taskMessages = downstreamMessage.taskList.task;
      final tasks = <Task>[];
      for (final task in taskMessages) {
        final scheduledOn = DateTime.fromMillisecondsSinceEpoch(task.scheduledOn.toInt());
        if (task.hasTakeImage()) {
          final takeImage = task.takeImage;
          tasks.add(
            TakeImageTask(
              scheduledOn: scheduledOn,
              plannedPosition: Offset(takeImage.plannedPositionX.toDouble(), takeImage.plannedPositionY.toDouble()),
              actualPosition:
                  takeImage.hasActualPositionX() && takeImage.hasActualPositionY()
                      ? Offset(takeImage.actualPositionX.toDouble(), takeImage.actualPositionY.toDouble())
                      : null,
            ),
          );
        } else if(task.hasSwitchState()) {
          tasks.add(
            SwitchStateTask(scheduledOn: scheduledOn, newState: _mapState(task.switchState))
          );
        } else if(task.hasVelocityChange()) {
          tasks.add(
              ChangeVelocityTask(scheduledOn: scheduledOn)
          );
        }
      }
      this.tasks.value = RemoteData(timestamp: DateTime.now(), data: tasks);
    }
  }

  SatelliteState _mapState(proto.SatelliteState state) {
    switch (state) {
      case proto.SatelliteState.acquisition:
        return SatelliteState.acquisition;
      case proto.SatelliteState.charge:
        return SatelliteState.charge;
      case proto.SatelliteState.communication:
        return SatelliteState.communication;
      case proto.SatelliteState.deployment:
        return SatelliteState.deployment;

      case proto.SatelliteState.safe:
        return SatelliteState.safe;
      case proto.SatelliteState.transition:
        return SatelliteState.transition;
      case proto.SatelliteState.none:
      default:
        return SatelliteState.none;
    }
  }
  Future<void> restartMelvinOb() async {
    final protocolClient = _protocolClient;
    if (protocolClient is SSHMelvinProtocolClient) {
      await protocolClient.restartMelvinOb();
    }
  }

  @disposeMethod
  void dispose() {
    _closed = true;
    _pendingSubmitTimeout?.cancel();
    _pendingSubmitTimeout = null;
    final pendingSubmit = _pendingSubmit;
    _pendingSubmit = null;
    pendingSubmit?.completeError(Exception("connection closed"));
    _downstreamSubscription?.cancel();
    _downstreamSubscription = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _protocolClient.close();
  }
}

abstract class MelvinProtocolClient {
  Stream<Uint8List> get receiveStream;

  Stream<proto.Downstream> get downstream => receiveStream.transform(MessageParserStreamTransformer());

  Future<MelvinConnectionState> tryConnect();

  Future<void> send(proto.Upstream upstreamProto) async {
    final payload = upstreamProto.writeToBuffer();
    final lengthField = Uint8List(4);
    lengthField.buffer.asByteData().setInt32(0, payload.length);
    _write(lengthField);
    _write(payload);
    await _flush();
  }

  void _write(Uint8List data);

  Future<void> _flush() => Future.value();

  Future close();
}

class LocalMelvinProtocolClient extends MelvinProtocolClient {
  Socket? _socket;

  @override
  Future<MelvinConnectionState> tryConnect() async {
    try {
      await _socket?.close();
    } catch (e) {
      // ignoring
    }
    try {
      final socket = await Socket.connect("localhost", 1337);
      _socket = socket;
    } catch (e) {
      return MelvinConnectionState.connectedToMachine;
    }
    return MelvinConnectionState.connectedToMachineAndMelvin;
  }

  @override
  void _write(Uint8List data) => _socket!.add(data);

  @override
  Future<void> _flush() => _socket!.flush();

  @override
  Future<void> close() async {
    await _socket?.close();
  }

  @override
  Stream<Uint8List> get receiveStream => _socket!;
}

class SSHMelvinProtocolClient extends MelvinProtocolClient {
  static const String stopMelvinCommand = "tmux kill-session -t melvin-runner";
  static const String startMelvinCommand =
      "cd /home && tmux new-session -d -s melvin-runner 'DRS_BASE_URL=http://10.100.10.3:33000 /home/melvin-ob'";
  SSHClient? _sshClient;
  SSHForwardChannel? _channel;

  @override
  Future<MelvinConnectionState> tryConnect() async {
    var sshClient = _sshClient;
    if (sshClient == null || sshClient.isClosed) {
      _channel = null;
      _sshClient = null;
      try {
        final socket = await SSHSocket.connect('10.100.10.3', 22);

        sshClient = SSHClient(socket, username: 'root', onPasswordRequest: () => 'password');
        _sshClient = sshClient;
      } catch (e, stack) {
        debugPrintStack(label: "Could not connect to ssh", stackTrace: stack);
        return MelvinConnectionState.notConnected;
      }
    }
    _channel?.close();
    final SSHForwardChannel channel;
    try {
      channel = await sshClient.forwardLocal("localhost", 1337);
    } catch (e) {
      try {
        await startMelvinOb();
      } catch (e, stack) {
        debugPrintStack(label: "Could not start melvin", stackTrace: stack);
      }
      return MelvinConnectionState.connectedToMachine;
    }
    _channel = channel;
    return MelvinConnectionState.connectedToMachineAndMelvin;
  }

  @override
  Stream<Uint8List> get receiveStream => _channel!.stream;

  Future<void> startMelvinOb() async {
    final sshClient = _sshClient;
    if (sshClient == null) return;
    await sshClient.run(startMelvinCommand);
  }

  Future<void> restartMelvinOb() async {
    final sshClient = _sshClient;
    if (sshClient == null) return;
    await sshClient.run("$stopMelvinCommand;$startMelvinCommand");
  }

  @override
  void _write(Uint8List data) async {
    if (_channel == null) throw Exception("Melvin not running");
    _channel!.sink.add(data);
  }

  @override
  Future<void> close() async {
    await _channel?.close();
    _sshClient?.close();
  }
}

class MessageParserStreamTransformer extends StreamTransformerBase<Uint8List, proto.Downstream> {
  @override
  Stream<proto.Downstream> bind(Stream<Uint8List> stream) =>
      Stream.eventTransformed(stream, (sink) => MessageParserStreamTransformerEventSink(sink));
}

class MessageParserStreamTransformerEventSink implements EventSink<Uint8List> {
  final EventSink<proto.Downstream> _sink;

  final List<int> buffer = [];
  int? _currentLength;

  MessageParserStreamTransformerEventSink(this._sink);

  @override
  void add(Uint8List event) {
    buffer.addAll(event);

    int position = 0;
    while (position < buffer.length) {
      if (_currentLength == null) {
        if ((buffer.length - position) >= 4) {
          _currentLength = Uint8List.fromList(buffer.sublist(position, position + 4)).buffer.asByteData().getUint32(0);
          position += 4;
        } else {
          break;
        }
      }
      if (_currentLength! <= (buffer.length - position)) {
        final payload = buffer.sublist(position, position + _currentLength!);
        position += _currentLength!;
        _currentLength = null;
        final message = proto.Downstream.fromBuffer(payload);
        _sink.add(message);
      } else {
        break;
      }
    }
    if (position > 0) {
      buffer.removeRange(0, position);
    }
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _sink.addError(error, stackTrace);
  }

  @override
  void close() {
    _sink.close();
  }
}

Future<ui.Image> _composeImage(int positionX, int positionY, Uint8List bytes, ui.Image? oldImage) async {
  final height = MapWidget.mapHeightDisplaySpace.toInt();
  final width = MapWidget.mapWidthDisplaySpace.toInt();
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final codec = await PaintingBinding.instance.instantiateImageCodecWithSize(buffer);
  final frameInfo = await codec.getNextFrame();
  final newImage = frameInfo.image;
  if (newImage.height == height && newImage.width == width) {
    return newImage;
  } else {
    final newImagePixels = (await newImage.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint32List();
    final Uint32List oldImagePixels;
    if (oldImage != null) {
      oldImagePixels = (await oldImage.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint32List();
    } else {
      oldImagePixels = Uint32List(height * width);
    }

    int oldImageCurrentOffset = positionY * width;
    int newImageCurrentOffset = 0;

    for (int newImageY = 0; newImageY < newImage.height; newImageY++) {
      for (int newImageX = 0; newImageX < newImage.width; newImageX++) {
        var x = newImageX + positionX;
        if (x >= width) x -= width;
        final newPixel = newImagePixels[newImageCurrentOffset + newImageX];
        if (newPixel == 0) continue;
        oldImagePixels[oldImageCurrentOffset + x] = newPixel;
      }
      oldImageCurrentOffset += width;
      if (oldImageCurrentOffset >= oldImagePixels.length) {
        oldImageCurrentOffset = 0;
      }
      newImageCurrentOffset += newImage.width;
    }

    final codec =
        await ui.ImageDescriptor.raw(
          await ui.ImmutableBuffer.fromUint8List(oldImagePixels.buffer.asUint8List()),
          width: width,
          height: height,
          pixelFormat: ui.PixelFormat.rgba8888,
        ).instantiateCodec();
    final frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }
}
