import 'package:ciarc_console/main.dart';
import 'package:ciarc_console/model/announcement.dart';
import 'package:ciarc_console/service/ground_station_client.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnnouncementsTab extends StatelessWidget {
  final GroundStationClient _groundStationClient = getIt.get();
  static final DateFormat _dateFormat = DateFormat.MEd("de_DE").add_Hm();

  AnnouncementsTab({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: _groundStationClient.announcements,
    builder: (context, announcements, widget) {
      if (announcements == null) {
        return Center(child: CircularProgressIndicator());
      } else if (announcements.isEmpty) {
        return Center(child: Text("No announcements available yet"));
      }

      return ListView.separated(
        itemBuilder: (context, index) {
          final announcement = announcements[announcements.length - index - 1];
          return ListTile(
            leading: announcement.severity == AnnouncementSeverity.error ? Icon(Icons.error_outline) : null,
            title: Text(announcement.message),
            subtitle: Text(_dateFormat.format(announcement.timestamp)),
          );
        },
        separatorBuilder: (context, index) => Divider(indent: 5, height: 2, thickness: 1,),
        itemCount: announcements.length,
      );
    },
  );
}
