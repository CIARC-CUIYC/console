import 'package:ciarc_console/main.dart';
import 'package:ciarc_console/service/ground_station_client.dart';
import 'package:ciarc_console/ui/map_widget.dart';
import 'package:flutter/material.dart';

class ControlTab extends StatefulWidget {
  const ControlTab({super.key});

  @override
  State<StatefulWidget> createState() => _ControlTabState();
}

class _ControlTabState extends State<ControlTab> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    //return MapWidget(hightlightArea: Rect.fromLTRB(2087, 600, 2687, 1200));
    return MapWidget(highlightArea: Rect.fromLTRB(13831, 6248, 16749, 7258));

  }
}
