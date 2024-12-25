import 'package:ciarc_console/main.dart';
import 'package:ciarc_console/model/announcement.dart';
import 'package:ciarc_console/service/ground_station_client.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnnouncementsTab extends StatefulWidget {
  const AnnouncementsTab({super.key});

  @override
  State<StatefulWidget> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<AnnouncementsTab> {
  final GroundStationClient groundStationClient = getIt.get();
  static final DateFormat _dateFormat = DateFormat.MEd("de_DE").add_Hm();

  List<Announcement>? _announcements;

  @override
  void initState() {
    super.initState();
    groundStationClient.addAnnouncementsListener(_onAnnouncementsChanged);
  }

  @override
  Widget build(BuildContext context) {
    final announcements = _announcements;
    if (announcements == null) {
      return Center(child: CircularProgressIndicator());
    } else if (announcements.isEmpty) {
      return Center(child: Text("No announcements available yet."));
    }

    return ListView.separated(
      itemBuilder: (context, index) {
        final announcement = announcements[index];
        return ListTile(
          leading: announcement.severity == AnnouncementSeverity.error ? Icon(Icons.error_outline) : null,
          title: Text(announcement.message),
          subtitle: Text(_dateFormat.format(announcement.timestamp)),
        );
      },
      separatorBuilder: (context, index) => Divider(indent: 5),
      itemCount: announcements.length,
    );
  }

  @override
  void dispose() {
    super.dispose();
    groundStationClient.removeAnnouncementsListener(_onAnnouncementsChanged);
  }

  void _onAnnouncementsChanged(List<Announcement> announcements) {
    setState(() {
      _announcements = announcements;
    });
  }
}
