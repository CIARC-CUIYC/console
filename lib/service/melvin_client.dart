import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:ciarc_console/model/telemetry.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';

import '../model/common.dart';
import '../model/melvin_messages.pb.dart' as proto;
import '../ui/map_widget.dart';

@singleton
class MelvinClient {
  MelvinProtocolClient? _protocolClient;
  Timer? _retryTimer;
  StreamSubscription<proto.Downstream>? _downstreamSubscription;
  ValueNotifier<ui.Image?> mapImage = ValueNotifier(null);
  ValueNotifier<RemoteData<Telemetry>?> telemetry = ValueNotifier(null);
  bool _closed = false;
  int lastSnapshot = 0;

  MelvinClient() {
    _tryConnect();
  }

  Future<void> _tryConnect() async {
    try {
      _protocolClient = await SSHMelvinProtocolClient.connectSSH();
    } catch (e) {
      // ignore
      _retryTimer = Timer(Duration(seconds: 5), _tryConnect);
      return;
    }
    _retryTimer = null;
    _downstreamSubscription = _protocolClient!.downstream.listen(_onDownstreamMessage, onDone: _restart);

    if (mapImage.value == null) {
      _protocolClient!.send(proto.Upstream(getFullImage: proto.Upstream_GetFullImage()));
    } else {
      _protocolClient!.send(proto.Upstream(getSnapshotImage: proto.Upstream_GetSnapshotDiffImage()));
    }
  }

  void _restart() {
    if (!_closed) {
      _downstreamSubscription?.cancel();
      _downstreamSubscription = null;
      _protocolClient?.close();
      _protocolClient = null;
      _tryConnect();
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
        _protocolClient?.send(proto.Upstream(createSnapshotImage: proto.Upstream_CreateSnapshotImage()));
        lastSnapshot = 0;
      }
    } else if (downstreamMessage.hasTelemetry()) {
      final telemetryMessage = downstreamMessage.telemetry;
      SatelliteState mapState(proto.SatelliteState state) {
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

      telemetry.value = RemoteData(
        timestamp: DateTime.fromMillisecondsSinceEpoch(telemetryMessage.timestamp.toInt()),
        data: Telemetry(
          state: mapState(telemetryMessage.state),
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
    _downstreamSubscription?.cancel();
    _downstreamSubscription = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _protocolClient?.close();
  }
}

abstract class MelvinProtocolClient {
  final Stream<proto.Downstream> downstream;

  MelvinProtocolClient._internal(Stream<Uint8List> stream)
    : downstream = stream.transform(MessageParserStreamTransformer());

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
  final Socket _socket;

  LocalMelvinProtocolClient._internal(this._socket) : super._internal(_socket);

  static Future<LocalMelvinProtocolClient> connect() async {
    final socket = await Socket.connect("localhost", 1337);
    return LocalMelvinProtocolClient._internal(socket);
  }

  @override
  void _write(Uint8List data) => _socket.add(data);

  @override
  Future<void> _flush() => _socket.flush();

  @override
  Future close() {
    return _socket.close();
  }
}

class SSHMelvinProtocolClient extends MelvinProtocolClient {
  final SSHClient _sshClient;
  final SSHForwardChannel _channel;

  SSHMelvinProtocolClient._internal(this._sshClient, this._channel) : super._internal(_channel.stream);

  static Future<MelvinProtocolClient> connectSSH() async {
    final client = SSHClient(
      await SSHSocket.connect('10.100.10.3', 22),
      username: 'root',
      onPasswordRequest: () => 'password',
    );

    try {
      final channel = await client.forwardLocal("localhost", 1337);
      return SSHMelvinProtocolClient._internal(client, channel);
    } catch (e) {
      client.close();
      rethrow;
    }
  }

  Future<void> restartMelvinOb() async {
    final session = await _sshClient.execute("tmux kill-session -t melvin-runner; tmux new-session -d -s melvin-runner 'DRS_BASE_URL=http://10.100.10.3:33000 ./melvin-ob'");
    session.close();
    await session.done;
  }

  @override
  void _write(Uint8List data) async {
    _channel.sink.add(data);
  }

  @override
  Future close() async {
    await _channel.close();
    _sshClient.close();
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
        final x = (newImageX + positionX) >= width ? newImageX - width : newImageX + positionX;
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
