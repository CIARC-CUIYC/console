import 'dart:async';
import 'dart:convert';
import 'package:ciarc_console/model/common.dart';
import 'package:ciarc_console/model/objective.dart';
import 'package:ciarc_console/model/telemetry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';

import '../model/achievement.dart';
import '../model/announcement.dart';
import '../model/slot.dart';

typedef AnnouncementListener = void Function(List<Announcement>);

class AutoRefresher<T> {
  Timer? _timer;
  bool _currentlyRefreshing = false;

  final Duration refreshPeriod;
  final ValueNotifier<T> notifier;
  final Future<T> Function() fetcher;

  AutoRefresher(this.notifier, this.fetcher, {this.refreshPeriod = const Duration(minutes: 10)});

  void _onTimerRefresh() {
    _timer = null;
    refresh();
  }

  Future<void> refresh() async {
    if (_currentlyRefreshing) return;
    _currentlyRefreshing = true;
    try {
      final result = await fetcher();
      notifier.value = result;
    } catch (e) {
      // ignore
    }
    _currentlyRefreshing = false;
    _timer ??= Timer(refreshPeriod, _onTimerRefresh);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

@singleton
class GroundStationClient {
  static const String baseUrl = "http://10.100.50.1:33000";
  static const String slotsUrl = "$baseUrl/slots";
  static const String achievementsUrl = "$baseUrl/achievements";
  static const String objectivesUrl = "$baseUrl/objective";
  static const String announcementsUrl = "$baseUrl/announcements";
  static const String observationUrl = "$baseUrl/observation";

  final ValueNotifier<List<Announcement>?> announcements = ValueNotifier(null);
  final ValueNotifier<RemoteData<List<Achievement>>?> achievements = ValueNotifier(null);
  final ValueNotifier<RemoteData<List<Objective>>?> objectives = ValueNotifier(null);
  final ValueNotifier<RemoteData<List<Slot>>?> slots = ValueNotifier(null);
  final ValueNotifier<RemoteData<Telemetry>?> telemetry = ValueNotifier(null);

  late final AutoRefresher<RemoteData<List<Achievement>>?> _achievementsRefresher;
  late final AutoRefresher<RemoteData<List<Objective>>?> _objectivesRefresher;
  late final AutoRefresher<RemoteData<Telemetry>?> _telemetryRefresher;
  late final AutoRefresher<RemoteData<List<Slot>>?> _slotsRefresher;
  StreamSubscription<SseEvent>? _announcementsSseSubscription;

  GroundStationClient() {
    _achievementsRefresher = AutoRefresher(achievements, () async {
      final data = await _getAchievements();
      return RemoteData(timestamp: DateTime.timestamp(), data: data);
    });

    _objectivesRefresher = AutoRefresher(objectives, () async {
      final data = await _getObjectives();
      return RemoteData(timestamp: DateTime.timestamp(), data: data);
    });

    _slotsRefresher = AutoRefresher(slots, () async {
      final data = await _getSlots();
      return RemoteData(timestamp: DateTime.timestamp(), data: data);
    });

    _telemetryRefresher = AutoRefresher(telemetry, _getTelemetry, refreshPeriod: Duration(seconds: 2));
    _start();
  }

  Future<void> _start() async {
    refresh();
    await _startListeningForAnnouncements();
  }

  void refresh() {
    _achievementsRefresher.refresh();
    _objectivesRefresher.refresh();
    _slotsRefresher.refresh();
    _telemetryRefresher.refresh();
  }

  Future<void> _startListeningForAnnouncements() async {
    if (_announcementsSseSubscription != null) Future.value();
    final client = http.Client();
    final response = await client.send(http.Request("GET", Uri.parse(announcementsUrl)));
    if (response.statusCode ~/ 100 != 2) throw Exception("could not subscribe");
    announcements.value ??= [];
    _announcementsSseSubscription = response.stream
        .transform(Utf8Decoder())
        .transform(LineSplitter())
        .transform(SseStreamTransformer())
        .listen((event) {
          final currentAnnouncements = announcements.value ?? [];
          currentAnnouncements.add(_parseAnnouncement(event));
          announcements.value = currentAnnouncements;
        });
  }

  void _stopListeningForAnnouncements() {
    final announcementsSseSubscription = _announcementsSseSubscription;
    if (announcementsSseSubscription == null) return;
    announcementsSseSubscription.cancel();
  }

  Future<RemoteData<Telemetry>> _getTelemetry() async {
    final response = await http.get(Uri.parse(observationUrl));
    if (response.statusCode ~/ 100 != 2) throw Exception("could get telemetry");
    final Map jsonResponse = const JsonDecoder().convert(response.body);
    return RemoteData(
      timestamp: DateTime.parse(jsonResponse["timestamp"]),
      data: Telemetry(
        state: SatelliteState.values.firstWhere(
          (value) => value.name == jsonResponse["state"],
          orElse: () => SatelliteState.none,
        ),
        position: Offset(jsonResponse["width_x"].toDouble(), jsonResponse["height_y"].toDouble()),
        velocity: Offset(jsonResponse["vx"].toDouble(), jsonResponse["vy"].toDouble()),
        battery: jsonResponse["battery"].toDouble(),
        fuel: jsonResponse["fuel"].toDouble(),
        dataVolume: (
          jsonResponse["data_volume"]["data_volume_sent"],
          jsonResponse["data_volume"]["data_volume_received"],
        ),
        distanceCovered: jsonResponse["distance_covered"].toDouble(),
        objectivesDone: jsonResponse["objectives_done"],
        objectivesPoints: jsonResponse["objectives_points"],
      ),
    );
  }

  Future<List<Achievement>> _getAchievements() async {
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

  Future<List<Slot>> _getSlots() async {
    final response = await http.get(Uri.parse(slotsUrl));
    if (response.statusCode ~/ 100 != 2) throw Exception("could not get slots");
    final Map jsonResponse = const JsonDecoder().convert(response.body);
    final slotsJson = jsonResponse["slots"] as List;
    return slotsJson
        .map(
          (achievementJson) => Slot(
            id: achievementJson["id"],
            start: DateTime.parse(achievementJson["start"]),
            end: DateTime.parse(achievementJson["end"]),
            booked: achievementJson["enabled"],
          ),
        )
        .toList(growable: false);
  }

  Future<void> bookSlot(int id, {bool unBook = false}) async {
    final response = await http.put(Uri.parse("$slotsUrl?slot_id=$id&enabled=${!unBook}"));
    if (response.statusCode ~/ 100 != 2) throw Exception("could not book slot");
    final slotsData = slots.value;
    slotsData?.data.firstWhere((slot) => slot.id == id).booked = !unBook;
    slots.value = slotsData;
    _slotsRefresher.refresh();
  }

  Future<List<Objective>> _getObjectives() async {
    final response = await http.get(Uri.parse(objectivesUrl));
    if (response.statusCode ~/ 100 != 2) throw Exception("could get objectives");
    final Map jsonResponse = const JsonDecoder().convert(response.body);
    final zonedObjectivesJson = jsonResponse["zoned_objectives"] as List;
    final beaconObjectivesJson = jsonResponse["beacon_objectives"] as List;
    dynamic parseZone(dynamic zone) {
      if (zone is List) {
        return Rect.fromLTRB(zone[0].toDouble(), zone[1].toDouble(), zone[2].toDouble(), zone[3].toDouble());
      } else {
        return zone;
      }
    }

    final objectives = [
      for (final zonedObjectiveJson in zonedObjectivesJson)
        ZonedObjective(
          id: zonedObjectiveJson["id"],
          name: zonedObjectiveJson["name"],
          description: zonedObjectiveJson["description"],
          start: DateTime.parse(zonedObjectiveJson["start"]),
          end: DateTime.parse(zonedObjectiveJson["end"]),
          decreaseRate: zonedObjectiveJson["decrease_rate"],
          zone: parseZone(zonedObjectiveJson["zone"]),
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
        return;
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
