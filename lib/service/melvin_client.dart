import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:ciarc_console/model/telemetry.dart';
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

  MelvinClient() {
    _tryConnect();
  }

  Future<void> _tryConnect() async {
    try {
      _protocolClient = await MelvinProtocolClient.connect();
    } catch (e) {
      // ignore
      _retryTimer = Timer(Duration(seconds: 5), _tryConnect);
      return;
    }
    _retryTimer = null;
    _downstreamSubscription = _protocolClient!.downstream.listen(_onDownstreamMessage, onDone: _restart);

    _protocolClient!.send(proto.Upstream(ping: proto.Upstream_Ping(echo: "Hello Melvin")));
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

class MelvinProtocolClient {
  final Socket _socket;
  final Stream<proto.Downstream> downstream;

  MelvinProtocolClient._internal(this._socket) : downstream = _socket.transform(MessageParserStreamTransformer());

  static Future<MelvinProtocolClient> connect() async {
    final socket = await Socket.connect("localhost", 1337);
    return MelvinProtocolClient._internal(socket);
  }

  Future<void> send(proto.Upstream upstreamProto) async {
    final payload = upstreamProto.writeToBuffer();
    final lengthField = Uint8List(4);
    lengthField.buffer.asByteData().setInt32(0, payload.length);
    _socket.add(lengthField);
    _socket.add(payload);
    await _socket.flush();
  }

  Future close() {
    return _socket.close();
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
    final newImageBytes = (await newImage.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint32List();
    final Uint32List oldImageBytes;
    if (oldImage != null) {
      oldImageBytes = (await oldImage.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint32List();
    } else {
      oldImageBytes = Uint32List(height * width);
    }

    final oldImagePosStart = positionY * width + positionX;
    int oldImageCurrentOffset = oldImagePosStart;
    int newImageCurrentOffset = 0;

    for (int y = 0; y < newImage.height; y++) {
      for (int x = 0; x < newImage.width; x++) {
        oldImageBytes[oldImageCurrentOffset + x] = newImageBytes[newImageCurrentOffset + x];
      }
      oldImageCurrentOffset += width;
      newImageCurrentOffset += newImage.width;
    }

    final codec =
        await ui.ImageDescriptor.raw(
          await ui.ImmutableBuffer.fromUint8List(oldImageBytes.buffer.asUint8List()),
          width: width,
          height: height,
          pixelFormat: ui.PixelFormat.rgba8888,
        ).instantiateCodec();
    final frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }
}
