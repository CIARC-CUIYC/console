import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../model/melvin_messages.pb.dart' as proto;

@singleton
class MelvinClient {
  MelvinProtocolClient? _protocolClient;
  Timer? _retryTimer;

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
    _protocolClient!.downstream.listen((m) {
      debugPrint("Incoming downstream:\n${m.toDebugString()}");
    });

    _protocolClient!.send(proto.Upstream(ping: proto.Upstream_Ping(echo: "Hello Melvin")));
  }

  @disposeMethod
  void dispose() {
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
