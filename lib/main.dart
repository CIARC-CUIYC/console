import 'package:ciarc_console/ui/announcements_tab.dart';
import 'package:ciarc_console/ui/objectives_tab.dart';
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple), useMaterial3: true),
      home: DefaultTabController(
        length: 4,
        child: Scaffold(
          body: TabBarView(
            children: [
              Center(child: Text("Control")),
              ObjectivesTab(),
              Center(child: Text("Achievements")),
              AnnouncementsTab(),
            ],
          ),
          bottomNavigationBar: const TabBar(
            tabs: [
              Tab(text: "Control", icon: Icon(Icons.control_camera)),
              Tab(text: "Objectives", icon: Icon(Icons.radar)),
              Tab(text: "Achievements", icon: Icon(Icons.leaderboard)),
              Tab(text: "Announcements", icon: Icon(Icons.newspaper)),
            ],
          ),
        ),
      ),
    );
  }
}
