import 'dart:async';
import 'dart:convert';
import 'package:ciarc_console/model/melvin_message.dart';
import 'package:ciarc_console/model/objective.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';

import '../model/achievement.dart';
import '../model/announcement.dart';

typedef AnnouncementListener = void Function(List<Announcement>);

@singleton
class GroundStationClient {
  static const String baseUrl = "http://10.100.50.1:33000";
  static const String slotsUrl = "$baseUrl/slots";
  static const String achievementsUrl = "$baseUrl/achievements";
  static const String objectivesUrl = "$baseUrl/objective";
  static const String announcementsUrl = "$baseUrl/announcements";

  final List<AnnouncementListener> _announcementsListeners = [];
  final List<Announcement> _currentAnnouncements = [];
  StreamSubscription<SseEvent>? _announcementsSseSubscription;

  Future<void> addAnnouncementsListener(AnnouncementListener listener) async {
    await _startListeningForAnnouncements();
    _announcementsListeners.add(listener);
    listener(_currentAnnouncements);
  }

  void removeAnnouncementsListener(AnnouncementListener listener) {
    _announcementsListeners.remove(listener);
    if (_announcementsListeners.isEmpty) {
      _stopListeningForAnnouncements();
    }
  }

  Future<void> _startListeningForAnnouncements() async {
    if (_announcementsSseSubscription != null) Future.value();
    final client = http.Client();
    final response = await client.send(http.Request("GET", Uri.parse(announcementsUrl)));
    if (response.statusCode ~/ 100 != 2) throw Exception("could not subscribe");
    _announcementsSseSubscription = response.stream
        .transform(Utf8Decoder())
        .transform(LineSplitter())
        .transform(SseStreamTransformer())
        .listen((event) {
          _currentAnnouncements.add(_parseAnnouncement(event));
          for (final listener in _announcementsListeners) {
            try {
              listener(_currentAnnouncements);
            } catch (e, stack) {
              Zone.current.handleUncaughtError(e, stack);
            }
          }
        });

    await Future.delayed(Duration(seconds: 1)); // XXX Wait until we received all initial announcements
  }

  void _stopListeningForAnnouncements() {
    final announcementsSseSubscription = _announcementsSseSubscription;
    if (announcementsSseSubscription == null) return;
    announcementsSseSubscription.cancel();
  }

  Future<List<Achievement>> getAchievements() async {
    final response = await http.get(Uri.parse(achievementsUrl));
    if (response.statusCode ~/ 100 != 2) throw Exception("could get achievements");
    final Map jsonResponse = const JsonDecoder().convert(response.body);
    final achievementsJson = jsonResponse["achievements"] as List;
    return achievementsJson
        .map(
          (achievementJson) => Achievement(
            name: achievementJson["name"],
            done: achievementJson["done"],
            points: achievementJson["points"],
            description: achievementJson["description"],
            goalParameter: (achievementJson["goal_parameter_threshold"], achievementJson["goal_parameter"]),
          ),
        )
        .toList(growable: false);
  }

  Future<List<Objective>> getObjectives() async {
    final response = await http.get(Uri.parse(objectivesUrl));
    if (response.statusCode ~/ 100 != 2) throw Exception("could get objectives");
    final Map jsonResponse = const JsonDecoder().convert(response.body);
    final zonedObjectivesJson = jsonResponse["zoned_objectives"] as List;
    final beaconObjectivesJson = jsonResponse["beacon_objectives"] as List;
    final objectives = [
      for (final zonedObjectiveJson in zonedObjectivesJson)
        ZonedObjective(
          id: zonedObjectiveJson["id"],
          name: zonedObjectiveJson["name"],
          description: zonedObjectiveJson["description"],
          start: DateTime.parse(zonedObjectiveJson["start"]),
          end: DateTime.parse(zonedObjectiveJson["end"]),
          decreaseRate: zonedObjectiveJson["decrease_rate"],
          zone: zonedObjectiveJson["zone"],
          coverageRequired: zonedObjectiveJson["coverage_required"],
          opticRequired: CameraAngle.values.firstWhere(
            (value) => value.name == zonedObjectiveJson["optic_required"],
            orElse: () => CameraAngle.normal,
          ),
          sprite: zonedObjectiveJson["sprite"],
          secret: zonedObjectiveJson["secret"],
        ),
      for (final beaconObjectiveJson in beaconObjectivesJson)
        BeaconObjective(
          id: beaconObjectiveJson["id"],
          name: beaconObjectiveJson["name"],
          description: beaconObjectiveJson["description"],
          start: DateTime.parse(beaconObjectiveJson["start"]),
          end: DateTime.parse(beaconObjectiveJson["end"]),
          decreaseRate: beaconObjectiveJson["decrease_rate"],
          attemptsMade: beaconObjectiveJson["attempts_made"],
        ),
    ];

    objectives.sort((a, b) => Comparable.compare(a.start, b.end));
    return objectives;
  }

  @disposeMethod
  void dispose() {
    _announcementsListeners.clear();
    _currentAnnouncements.clear();
    _stopListeningForAnnouncements();
  }

  static Announcement _parseAnnouncement(SseEvent sseEvent) {
    final lines = sseEvent.data.split("\n");
    String message = "";
    String? event;

    for (final line in lines) {
      final colonPos = line.indexOf(":");
      if (colonPos == -1) continue;
      final fieldName = line.substring(0, colonPos);
      final fieldValue = line.substring(colonPos + 1).trim();
      if (fieldName == "data") {
        message += fieldValue;
      } else if (fieldName == "event") {
        event = fieldValue;
      }
    }

    final AnnouncementSeverity severity;
    switch (event) {
      case "ERROR":
        severity = AnnouncementSeverity.error;
        break;
      default:
        severity = AnnouncementSeverity.info;
        break;
    }

    DateTime? timestamp;
    int closingBracketPos = message.indexOf("]");
    if (message.startsWith("[") && closingBracketPos != -1) {
      final timeSinceEpoch = int.tryParse(message.substring(1, closingBracketPos));
      if (timeSinceEpoch != null) timestamp = DateTime.fromMillisecondsSinceEpoch(timeSinceEpoch * 1000);
      message = message.substring(closingBracketPos + 1).trim();
    }

    return Announcement(timestamp ?? DateTime.timestamp(), severity, message);
  }
}

class SseEvent {
  final String type;
  final String? id;
  final String data;

  SseEvent({required this.type, required this.id, required this.data});
}

class SseStreamTransformer extends StreamTransformerBase<String, SseEvent> {
  @override
  Stream<SseEvent> bind(Stream<String> stream) =>
      Stream.eventTransformed(stream, (sink) => SseStreamTransformerEventSink(sink));
}

class SseStreamTransformerEventSink implements EventSink<String> {
  final EventSink<SseEvent> _sseEventSink;
  String _currentEventType = "";
  String _currentData = "";
  String? _currentId;

  SseStreamTransformerEventSink(this._sseEventSink);

  @override
  void add(String line) {
    if (line.isEmpty) {
      if (_currentData.isEmpty) {
        _currentEventType = "";
      } else if (_currentData.endsWith("\n")) {
        _currentData.substring(0, _currentData.length - 1);
      }
      _sseEventSink.add(
        SseEvent(
          type: _currentEventType.isNotEmpty ? _currentEventType : "message",
          id: _currentId,
          data: _currentData,
        ),
      );
      _currentEventType = "";
      _currentData = "";
    } else if (line.startsWith(":")) {
      return; // ignore comment
    } else {
      int colonIndex = line.indexOf(":");
      String fieldName;
      String fieldValue;
      if (colonIndex == -1) {
        fieldName = line;
        fieldValue = "";
      } else {
        fieldName = line.substring(0, colonIndex);
        if (colonIndex + 1 < line.length && line[colonIndex + 1] == " ") colonIndex++;
        fieldValue = line.substring(colonIndex + 1);
      }
      if (fieldName == "event") {
        _currentEventType = fieldValue;
      } else if (fieldName == "data") {
        _currentData += "$fieldValue\n";
      } else if (fieldName == "id") {
        _currentId = fieldValue;
      }
    }
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _sseEventSink.addError(error, stackTrace);
  }

  @override
  void close() {
    _sseEventSink.close();
  }
}
