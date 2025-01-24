import 'package:ciarc_console/service/melvin_client.dart';
import 'package:flutter/material.dart';

import '../main.dart';

class ControlTab extends StatefulWidget {
  const ControlTab({super.key});

  @override
  State<StatefulWidget> createState() => _ControlTabState();
}

class _ControlTabState extends State<ControlTab> {
  final MelvinClient _melvinClient = getIt();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    //return MapWidget(hightlightArea: Rect.fromLTRB(2087, 600, 2687, 1200));
    return Column(
      children: [
        OutlinedButton.icon(
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
      ],
    );
  }
}
