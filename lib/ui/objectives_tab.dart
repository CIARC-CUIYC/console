import 'package:ciarc_console/service/melvin_client.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../model/objective.dart';
import '../service/ground_station_client.dart';
import 'time_ago.dart';

class ObjectivesTab extends StatefulWidget {
  final void Function(ZonedObjective? objective) onHover;

  const ObjectivesTab({super.key, required this.onHover});

  @override
  State<StatefulWidget> createState() => _ObjectivesTabState();
}

class _ObjectivesTabState extends State<ObjectivesTab> {
  final GroundStationClient _groundStationClient = getIt.get();
  static final DateFormat _dateFormat = DateFormat.MEd("de_DE").add_Hm();

  Objective? _currentHover;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder(
        valueListenable: _groundStationClient.objectives,
        builder: (context, objectives, widget_) {
          if (objectives == null) {
            return Center(child: CircularProgressIndicator());
          } else if (objectives.data.isEmpty) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text("No objectives available yet"),
                TimeAgo(
                    timestamp: objectives.timestamp, builder: (context, timeText) => Text("Last updated: $timeText")),
              ],
            );
          }

          final now = DateTime.now();

          return ListView.separated(
            itemBuilder: (context, index) {
              if (index == objectives.data.length) {
                return Container(
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: TimeAgo(
                    timestamp: objectives.timestamp,
                    builder: (context, timeText) => Text("Last updated: $timeText"),
                  ),
                );
              }
              final objective = objectives.data[index];
              return MouseRegion(
                child: ListTile(
                  textColor: now.isAfter(objective.end) ? Colors.grey : null,
                  leading: Icon(objective is BeaconObjective ? Icons.my_location_outlined : Icons.crop),
                  title: Text(objective.name),
                  subtitle: Text("${_dateFormat.format(objective.start)} - ${_dateFormat.format(objective.end)}"),
                  trailing:
                  objective is ZonedObjective
                      ? OutlinedButton(child: Icon(Icons.send), onPressed: () {
                    _showSubmitObjectiveDialog(objective);
                  })
                      : null,
                  onTap: () => _showDetailsSheet(objective),
                ),
                onEnter: (value) {
                  if (objective is ZonedObjective) {
                    _currentHover = objective;
                    widget.onHover(objective);
                  }
                },
                onExit: (value) {
                  if (_currentHover == objective) {
                    _currentHover = null;
                    widget.onHover(null);
                  }
                },
              );
            },
            separatorBuilder: (context, index) => Divider(indent: 5, height: 2, thickness: 1),
            itemCount: objectives.data.length + 1,
          );
        },
      );

  void _showDetailsSheet(Objective objective) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) =>
          Padding(
            padding: EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(objective.name, style: TextStyle(fontSize: 19)),
                    Icon(objective is BeaconObjective ? Icons.my_location_outlined : Icons.crop),
                  ],
                ),
                Text("${_dateFormat.format(objective.start)} - ${_dateFormat.format(objective.end)}"),
                Divider(),
                if (objective.description.isNotEmpty) ...[Text(objective.description), Divider()],
                Wrap(
                  spacing: 10,
                  children: [
                    Text("Decrease rate: ${objective.decreaseRate}"),
                    if (objective is BeaconObjective) Text("Attempts made: ${objective.attemptsMade}"),
                    if (objective is ZonedObjective) ...[
                      Text("Zone: ${objective.zone}"),
                      Text("Required coverage: ${objective.coverageRequired}"),
                      Text("Required optic: ${objective.opticRequired.name}"),
                      if (objective.sprite != null) Text("Sprite: ${objective.sprite}"),
                      if (objective.secret) Text("Secret"),
                    ],
                  ],
                ),
              ],
            ),
          ),
    );
  }

  void _showSubmitObjectiveDialog(ZonedObjective objective) {
    showDialog(context: context, builder: (context) => _SubmitObjectiveDialog(objective: objective));
  }
}

class _SubmitObjectiveDialog extends StatefulWidget {
  final ZonedObjective objective;

  const _SubmitObjectiveDialog({required this.objective});

  @override
  State<StatefulWidget> createState() => _SubmitObjectiveDialogState();

}

class _SubmitObjectiveDialogState extends State<_SubmitObjectiveDialog> {
  final GroundStationClient _groundStationClient = getIt.get();
  final MelvinClient _melvinClient = getIt.get();
  late Rect area;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    area = widget.objective.zone;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(title: Text("Submit objective #${widget.objective.id} - ${widget.objective.name}"),
      actions: [
        TextButton(
          onPressed: _processing ? null : () {
            _submit();
          },
          child: _processing ? CircularProgressIndicator() : const Text('Ok'),
        ),
        TextButton(
          onPressed: _processing ? null : () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        )
      ],);
  }

  Future<void> _submit() async {
    if (_processing) return;
    setState(() {
      _processing = true;
    });

    bool success;
    try {
      await _melvinClient.submitObjective(widget.objective.id!, area);
      success = true;
    } catch (e, stack) {
      debugPrintStack(label: "Submitting Objective failed", stackTrace: stack);
      success = false;
    }

    final ctx = context;
    if (ctx.mounted) {
      final String resultMessage;
      if(success) {
        resultMessage = "Submit objective successfully";
      } else {
        resultMessage = "Failed to submit objective";
      }
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(resultMessage)));
      Navigator.of(ctx).pop();
    }
    _groundStationClient.refresh();
  }

}
