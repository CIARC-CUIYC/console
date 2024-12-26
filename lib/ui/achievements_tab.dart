import 'package:flutter/material.dart';

import '../main.dart';
import '../model/achievement.dart';
import '../service/ground_station_client.dart';
import 'time_ago.dart';

class AchievementsTab extends StatelessWidget {
  AchievementsTab({super.key});

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
            return Container(
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(vertical: 10),
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
            onTap: () => _showDetailsSheet(context, achievement),
          );
        },
        separatorBuilder: (context, index) => Divider(indent: 5, height: 2, thickness: 1),
        itemCount: achievements.data.length + 1,
      );
    },
  );

  void _showDetailsSheet(BuildContext context, Achievement achievement) {
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
