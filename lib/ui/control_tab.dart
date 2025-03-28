import 'package:ciarc_console/model/task.dart';
import 'package:ciarc_console/service/melvin_client.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import 'time_ago.dart';

class ControlTab extends StatefulWidget {
  const ControlTab({super.key});

  @override
  State<StatefulWidget> createState() => _ControlTabState();
}

class _ControlTabState extends State<ControlTab> {
  static final DateFormat _dateFormat = DateFormat.MEd("de_DE").add_Hm();
  final MelvinClient _melvinClient = getIt();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {

    //return MapWidget(hightlightArea: Rect.fromLTRB(2087, 600, 2687, 1200));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.all(5),
          child: OutlinedButton.icon(
            onPressed: () async {
              try {
                await _melvinClient.restartMelvinOb();
              } on Exception {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Restart failed")));
                }
              }
            },
            label: Text("Restart Melvin OB"),
            icon: Icon(Icons.restart_alt),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: _melvinClient.tasks,
          builder: (context, tasksData, parent) {
            if (tasksData == null || tasksData.data.isEmpty) {
              return Center(child: Text("No tasks known"));
            } else {
              final tasks = tasksData.data;
              return ListView.separated(
                itemBuilder: (context, index) {
                  if (index == tasks.length) {
                    return Container(
                      alignment: Alignment.center,
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: TimeAgo(
                        timestamp: tasksData.timestamp,
                        builder: (context, timeText) => Text("Last updated: $timeText"),
                      ),
                    );
                  }
                  final task = tasks[index];
                  final IconData icon;
                  final String description;
                  if(task is TakeImageTask) {
                    icon = Icons.camera_alt;
                    description = task.plannedPosition.toString();
                  } else if(task is SwitchStateTask) {
                    icon = Icons.swap_horiz;
                    description = task.newState.toString();
                  } else if(task is ChangeVelocityTask) {
                    icon = Icons.rocket_launch;
                    description = "Velocity Change";
                  } else {
                    throw Exception("Unreachable");
                  }
                  return ListTile(leading: Icon(icon), title: Text(description), subtitle: Text(_dateFormat.format(task.scheduledOn)));
                },

                separatorBuilder: (context, index) => Divider(indent: 5, height: 2, thickness: 1),
                itemCount: tasks.length,
              );
            }
          },
        ),
      ],
    );
  }
}
