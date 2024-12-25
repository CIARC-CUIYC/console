import 'package:ciarc_console/main.dart';
import 'package:ciarc_console/service/ground_station_client.dart';
import 'package:flutter/material.dart';

import '../model/achievement.dart';

class AchievementsTab extends StatefulWidget {
  const AchievementsTab({super.key});

  @override
  State<StatefulWidget> createState() => _AchievementsTabState();
}

class _AchievementsTabState extends State<AchievementsTab> {
  final GroundStationClient _groundStationClient = getIt.get();

  List<Achievement>? _achievements;

  @override
  void initState() {
    super.initState();
    _groundStationClient.getAchievements().then(
      (achievements) => setState(() {
        _achievements = achievements;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final achievements = _achievements;
    if (achievements == null) {
      return Center(child: CircularProgressIndicator());
    } else if (achievements.isEmpty) {
      return Center(child: Text("No achievements available yet."));
    }

    return ListView.separated(
      itemBuilder: (context, index) {
        final achievement = achievements[index];
        return ListTile(
          trailing: achievement.done ? Icon(Icons.check) : null,
          title: Text(achievement.name),
          subtitle: Text("${achievement.points} Points"),
          onTap: () => _showDetailsSheet(achievement),
        );
      },
      separatorBuilder: (context, index) => Divider(indent: 5),
      itemCount: achievements.length,
    );
  }

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
