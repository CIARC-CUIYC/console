import 'package:ciarc_console/model/objective.dart';
import 'package:ciarc_console/service/ground_station_client.dart';
import 'package:ciarc_console/service/melvin_client.dart';
import 'package:ciarc_console/ui/achievements_tab.dart';
import 'package:ciarc_console/ui/announcements_tab.dart';
import 'package:ciarc_console/ui/control_tab.dart';
import 'package:ciarc_console/ui/map_widget.dart';
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

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Rect? _highlightedArea;
  void Function(Rect)? _onHighlightedAreaResized;

  final MelvinClient _melvinClient = getIt.get();

  @override
  void initState() {
    getIt.get<MelvinClient>();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CIARC Console',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightGreen), useMaterial3: false),
      home: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            if (orientation == Orientation.landscape) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: Material(
                      child: StatusPanel(
                        highlightedArea: _highlightedArea,
                        onHighlightAreaResized: _onHighlightedAreaResized,
                        compact: false,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Navigator(
                      onGenerateRoute:
                          (route) => MaterialPageRoute(
                            builder:
                                (context) => AppTabs(
                                  compact: false,
                                  onObjectiveHover: _onObjectiveHover,
                                  highlightedArea: _highlightedArea,
                                  registerResizableObjective: _registerResizableObjective,
                                ),
                          ),
                    ),
                  ),
                ],
              );
            } else {
              return AppTabs(compact: true, onObjectiveHover: _onObjectiveHover, highlightedArea: _highlightedArea);
            }
          },
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden) {
      _melvinClient.pause();
    } else if (state == AppLifecycleState.resumed) {
      _melvinClient.resume();
    }
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

  void _registerResizableObjective(void Function(Rect)? onResize) {
    setState(() {
      if (onResize == null) {
        _highlightedArea = null;
        _onHighlightedAreaResized = null;
      } else {
        _highlightedArea = Rect.fromCenter(
          center: Offset(MapWidget.mapWidth / 2, MapWidget.mapHeight / 2),
          width: MapWidget.mapWidth / 4,
          height: MapWidget.mapHeight / 4,
        );
        _onHighlightedAreaResized = onResize;
      }
    });
  }
}

class AppTabs extends StatefulWidget {
  final bool compact;
  final void Function(ZonedObjective? objective) onObjectiveHover;
  final void Function(HighlightResizedListener?)? registerResizableObjective;
  final Rect? highlightedArea;

  const AppTabs({
    super.key,
    required this.compact,
    required this.onObjectiveHover,
    this.highlightedArea,
    this.registerResizableObjective,
  });

  @override
  State<StatefulWidget> createState() => _AppTabsState();
}

class _AppTabsState extends State<AppTabs> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GroundStationClient _groundStationClient = getIt.get();

  @override
  void initState() {
    super.initState();
    _createTabController();
  }

  void _createTabController() {
    _tabController = TabController(length: widget.compact ? 6 : 5, vsync: this);
    _tabController.addListener(_onTabChange);
  }

  @override
  Widget build(BuildContext context) {
    final tabIndex = widget.compact ? _tabController.index - 1 : _tabController.index;

    return Scaffold(
      body: TabBarView(
        controller: _tabController,
        physics: tabIndex == -1 ? const NeverScrollableScrollPhysics() : null,
        children: [
          if (widget.compact) StatusPanel(highlightedArea: widget.highlightedArea, compact: true),
          ControlTab(),
          SlotsTab(),
          ObjectivesTab(
            onHover: widget.onObjectiveHover,
            registerResizableObjective: widget.registerResizableObjective,
          ),
          AchievementsTab(),
          AnnouncementsTab(),
        ],
      ),
      bottomNavigationBar: TabBar(
        controller: _tabController,
        labelColor: Colors.black54,
        labelStyle: TextStyle(fontSize: 13),
        labelPadding: EdgeInsets.zero,
        physics: tabIndex == -1 ? const NeverScrollableScrollPhysics() : null,
        tabs: [
          if (widget.compact) Tab(text: "Map", icon: Icon(Icons.map_outlined)),
          Tab(text: "Control", icon: Icon(Icons.control_camera)),
          Tab(text: "Com. Slots", icon: Icon(Icons.sync_alt)),
          Tab(text: "Objectives", icon: Icon(Icons.radar)),
          Tab(text: "Achievements", icon: Icon(Icons.leaderboard)),
          Tab(text: "Announcements", icon: Icon(Icons.newspaper)),
        ],
      ),
      floatingActionButton:
          tabIndex == 1 || tabIndex == 2 || tabIndex == 3
              ? FloatingActionButton.small(
                onPressed: () {
                  _groundStationClient.refresh();
                },
                child: Icon(Icons.refresh),
              )
              : null,
    );
  }

  @override
  void didUpdateWidget(covariant AppTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.compact != widget.compact) {
      _tabController.dispose();
      _createTabController();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChange);
    super.dispose();
  }

  void _onTabChange() => setState(() {});
}
