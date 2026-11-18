import 'package:flutter/material.dart';

import 'actuator_page.dart';
import 'dashboard_page.dart';
import 'history_page.dart';
import 'lab_repository.dart';
import 'sensor_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final LabRepository _repo = LabRepository.instance;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _repo.start(); // open the Firebase listeners once for the whole session
  }

  @override
  void dispose() {
    _repo.stop(); // close them when the user logs out
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          DashboardPage(),
          SensorPage(),
          ActuatorPage(),
          HistoryPage(),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: _repo,
        builder: (context, _) {
          final alert = _repo.deviceOnline && _repo.hazard;
          return NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            destinations: [
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: alert,
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.dashboard),
                ),
                label: 'Dashboard',
              ),
              const NavigationDestination(icon: Icon(Icons.sensors), label: 'Sensors'),
              const NavigationDestination(
                  icon: Icon(Icons.power_settings_new), label: 'Actuators'),
              const NavigationDestination(icon: Icon(Icons.history), label: 'History'),
            ],
          );
        },
      ),
    );
  }
}