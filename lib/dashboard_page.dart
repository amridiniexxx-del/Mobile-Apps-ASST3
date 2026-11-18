import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'lab_repository.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to view the lab.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log Out')),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseAuth.instance.signOut(); // AuthGate returns to the login page
    }
  }

  String _signalText(int rssi) {
    if (rssi == 0) return '--';
    if (rssi > -60) return 'Strong';
    if (rssi > -75) return 'Fair';
    return 'Weak';
  }

  String _lastSeenText(DateTime? t) {
    if (t == null) return 'never';
    final s = DateTime.now().difference(t).inSeconds;
    return s < 60 ? '${s}s ago' : '${s ~/ 60}m ago';
  }

  @override
  Widget build(BuildContext context) {
    final repo = LabRepository.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lab Safety Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log Out',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final offline = !repo.deviceOnline;
          final hazard = !offline && repo.hazard;

          final Color accent = offline
              ? Colors.grey
              : (hazard ? Colors.red : Colors.green);
          final IconData statusIcon = offline
              ? Icons.cloud_off_rounded
              : (hazard ? Icons.warning_rounded : Icons.check_circle_rounded);
          final String statusTitle = offline
              ? 'DEVICE OFFLINE'
              : (hazard ? 'HAZARD DETECTED!' : 'Lab Environment: SAFE');
          final String statusSub = offline
              ? 'No data from the ESP32. Showing last known values.'
              : (hazard
              ? (repo.autoOverride
              ? '${repo.hazardReason}. Automatic response: light & buzzer ON.'
              : '${repo.hazardReason}. Automatic response is disabled.')
              : 'All readings are within safe limits.');

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // ---- Overall lab safety status
              Card(
                color: accent.withOpacity(0.12),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 48, color: accent),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('System Safety Status',
                                style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(
                              statusTitle,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: accent,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(statusSub, style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ---- Device status
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _DeviceItem(
                        icon: Icons.memory,
                        label: 'ESP32',
                        value: offline ? 'Offline' : 'Online',
                        color: offline ? Colors.red : Colors.green,
                      ),
                      _DeviceItem(
                        icon: Icons.wifi,
                        label: 'Wi-Fi signal',
                        value: offline ? '--' : _signalText(repo.wifiRssi),
                        color: Colors.blue,
                      ),
                      _DeviceItem(
                        icon: Icons.shield,
                        label: 'Auto safety',
                        value: repo.autoSafety ? 'ON' : 'OFF',
                        color: repo.autoSafety ? Colors.green : Colors.orange,
                      ),
                      _DeviceItem(
                        icon: Icons.schedule,
                        label: 'Last update',
                        value: _lastSeenText(repo.lastSeen),
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text('Quick Telemetry Overview',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.3,
                children: [
                  _SummaryCard(
                    title: 'Temperature',
                    value: '${repo.temperature.toStringAsFixed(1)} °C',
                    icon: Icons.thermostat,
                    color: repo.temperature > repo.tempLimit ? Colors.red : Colors.orange,
                  ),
                  _SummaryCard(
                    title: 'Humidity',
                    value: '${repo.humidity.toStringAsFixed(0)} %',
                    icon: Icons.water_drop,
                    color: Colors.blue,
                  ),
                  _SummaryCard(
                    title: 'Gas / Smoke',
                    value: '${repo.gas} ADC',
                    icon: Icons.cloud,
                    color: repo.gas > repo.gasLimit ? Colors.red : Colors.deepOrange,
                  ),
                  _SummaryCard(
                    title: 'Light Level',
                    value: '${repo.ldr} ADC',
                    icon: Icons.wb_sunny,
                    color: Colors.amber[800]!,
                  ),
                  _SummaryCard(
                    title: 'Warning Light',
                    value: repo.relayOn ? 'ON' : 'OFF',
                    icon: Icons.lightbulb,
                    color: repo.relayOn ? Colors.green : Colors.grey,
                  ),
                  _SummaryCard(
                    title: 'Buzzer Alarm',
                    value: repo.buzzerOn ? 'ACTIVE' : 'MUTED',
                    icon: Icons.alarm,
                    color: repo.buzzerOn ? Colors.red : Colors.grey,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DeviceItem extends StatelessWidget {
  const _DeviceItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                value,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}