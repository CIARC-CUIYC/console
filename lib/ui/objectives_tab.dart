import 'package:ciarc_console/main.dart';
import 'package:ciarc_console/service/ground_station_client.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../model/objective.dart';

class ObjectivesTab extends StatefulWidget {
  final void Function(ZonedObjective? objective) onHover;

  const ObjectivesTab({super.key, required this.onHover});

  @override
  State<StatefulWidget> createState() => _ObjectivesTabState();
}

class _ObjectivesTabState extends State<ObjectivesTab> {
  final GroundStationClient _groundStationClient = getIt.get();
  static final DateFormat _dateFormat = DateFormat.MEd("de_DE").add_Hm();

  List<Objective>? _objectives;

  Objective? _currentHover;

  @override
  void initState() {
    super.initState();
    _groundStationClient.getObjectives().then(
      (objectives) => setState(() {
        _objectives = objectives;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final objectives = _objectives;
    if (objectives == null) {
      return Center(child: CircularProgressIndicator());
    } else if (objectives.isEmpty) {
      return Center(child: Text("No objectives available yet."));
    }

    final now = DateTime.now();

    return ListView.separated(
      itemBuilder: (context, index) {
        final objective = objectives[index];
        return MouseRegion(
          child: ListTile(
            textColor: now.isAfter(objective.end) ? Colors.grey : null,
            leading: Icon(objective is BeaconObjective ? Icons.my_location_outlined : Icons.crop),
            title: Text(objective.name),
            subtitle: Text("${_dateFormat.format(objective.start)} - ${_dateFormat.format(objective.end)}"),
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
      separatorBuilder: (context, index) => Divider(indent: 5),
      itemCount: objectives.length,
    );
  }

  void _showDetailsSheet(Objective objective) {
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
}
