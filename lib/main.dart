import 'package:ciarc_console/model/objective.dart';
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

import 'ui/slots_tab.dart';

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
  final GroundStationClient _groundStationClient = getIt.get();

  @override
  void initState() {
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChange);

    getIt.get<MelvinClient>();
    super.initState();
  }

  void _onTabChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CIARC Console',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightGreen), useMaterial3: false),
      home: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(flex: 3, child: Scaffold(body: StatusPanel(highlightedArea: _highlightedArea))),
          Expanded(
            flex: 2,
            child: Scaffold(
              body: TabBarView(
                controller: _tabController,
                children: [
                  ControlTab(),
                  SlotsTab(),
                  ObjectivesTab(onHover: _onObjectiveHover),
                  AchievementsTab(),
                  AnnouncementsTab(),
                ],
              ),
              bottomNavigationBar: TabBar(
                controller: _tabController,
                labelColor: Colors.black54,
                labelStyle: TextStyle(fontSize: 13),
                labelPadding: EdgeInsets.zero,
                tabs: [
                  Tab(text: "Control", icon: Icon(Icons.control_camera)),
                  Tab(text: "Com. Slots", icon: Icon(Icons.sync_alt)),
                  Tab(text: "Objectives", icon: Icon(Icons.radar)),
                  Tab(text: "Achievements", icon: Icon(Icons.leaderboard)),
                  Tab(text: "Announcements", icon: Icon(Icons.newspaper)),
                ],
              ),
              floatingActionButton:
                  _tabController.index == 1 || _tabController.index == 2 || _tabController.index == 3
                      ? FloatingActionButton.small(
                        onPressed: () {
                          _groundStationClient.refresh();
                        },
                        child: Icon(Icons.refresh),
                      )
                      : null,
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

  @override
  void dispose() {
    _tabController.removeListener(_onTabChange);
    super.dispose();
  }
}
