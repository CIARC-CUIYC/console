import 'package:ciarc_console/main.dart';
import 'package:ciarc_console/service/ground_station_client.dart';
import 'package:flutter/material.dart';

import '../model/achievement.dart';
import 'status_panel.dart';

class AchievementsTab extends StatefulWidget {
  const AchievementsTab({super.key});

  @override
  State<StatefulWidget> createState() => _AchievementsTabState();
}

class _AchievementsTabState extends State<AchievementsTab> {
  final GroundStationClient _groundStationClient = getIt.get();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: _groundStationClient.achievements,
    builder: (context, achievements, widget_) {
      if (achievements == null) {
        return Center(child: CircularProgressIndicator());
      } else if (achievements.data.isEmpty) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text("No achievements available yet"),
            TimeAgo(timestamp: achievements.timestamp, builder: (context, timeText) => Text("Last updated: $timeText")),
          ],
        );
      }

      return ListView.separated(
        itemBuilder: (context, index) {
          if (index == achievements.data.length) {
            return Center(
              child: TimeAgo(
                timestamp: achievements.timestamp,
                builder: (context, timeText) => Text("Last updated: $timeText"),
              ),
            );
          }
          final achievement = achievements.data[index];
          return ListTile(
            trailing: achievement.done ? Icon(Icons.check) : null,
            title: Text(achievement.name),
            subtitle: Text("${achievement.points} Points"),
            onTap: () => _showDetailsSheet(achievement),
          );
        },
        separatorBuilder: (context, index) => Divider(indent: 5),
        itemCount: achievements.data.length + 1,
      );
    },
  );

  void _showDetailsSheet(Achievement achievement) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Padding(
            padding: EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(achievement.name, style: TextStyle(fontSize: 19)),
                    if (achievement.done) Icon(Icons.check),
                  ],
                ),
                Text("${achievement.points} Points"),
                Divider(),
                if (achievement.description.isNotEmpty) ...[Text(achievement.description), Divider()],
                Text("Threshold : ${achievement.goalParameter.$1}"),
                Text("Scored : ${achievement.goalParameter.$2}"),
              ],
            ),
          ),
    );
  }
}
