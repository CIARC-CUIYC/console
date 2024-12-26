import 'package:ciarc_console/model/objective.dart';
import 'package:ciarc_console/model/telemetry.dart';
import 'package:ciarc_console/service/ground_station_client.dart';
import 'package:ciarc_console/service/melvin_client.dart';
import 'package:ciarc_console/ui/achievements_tab.dart';
import 'package:ciarc_console/ui/announcements_tab.dart';
import 'package:ciarc_console/ui/control_tab.dart';
import 'package:ciarc_console/ui/objectives_tab.dart';
import 'package:ciarc_console/ui/status_panel.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'main.config.dart';
import 'package:intl/date_symbol_data_local.dart';

final getIt = GetIt.instance;

@InjectableInit()
void configureDependencies() => getIt.init();

Future<void> main() async {
  await initializeDateFormatting('de_DE', null);
  configureDependencies();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<StatefulWidget> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Rect? _highlightedArea;
  Telemetry? _telemetry;

  @override
  void initState() {
    _tabController = TabController(length: 4, vsync: this);
    getIt.get<GroundStationClient>().getTelemetry().then(
      (telemetry) => setState(() {
        _telemetry = telemetry;
      }),
    );

    getIt.get<MelvinClient>();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CIARC Console',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightGreen), useMaterial3: true),
      home: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Scaffold(body: StatusPanel(telemetry: _telemetry, highlightedArea: _highlightedArea)),
          ),
          Expanded(
            flex: 2,
            child: Scaffold(
              body: TabBarView(
                controller: _tabController,
                children: [
                  ControlTab(),
                  ObjectivesTab(onHover: _onObjectiveHover),
                  AchievementsTab(),
                  AnnouncementsTab(),
                ],
              ),
              bottomNavigationBar: TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: "Control", icon: Icon(Icons.control_camera)),
                  Tab(text: "Objectives", icon: Icon(Icons.radar)),
                  Tab(text: "Achievements", icon: Icon(Icons.leaderboard)),
                  Tab(text: "Announcements", icon: Icon(Icons.newspaper)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onObjectiveHover(ZonedObjective? objective) {
    final zone = objective?.zone;
    setState(() {
      if (zone is Rect) {
        _highlightedArea = zone;
      } else {
        _highlightedArea = null;
      }
    });
  }
}
