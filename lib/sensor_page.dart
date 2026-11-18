import 'package:flutter/material.dart';

import 'lab_repository.dart';

class SensorPage extends StatelessWidget {
  const SensorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = LabRepository.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Live Sensor Telemetry')),
      body: ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final tempAlert = repo.temperature > repo.tempLimit;
          final gasAlert = repo.gas > repo.gasLimit;

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              if (!repo.deviceOnline)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.cloud_off, color: Colors.grey),
                      SizedBox(width: 8),
                      Expanded(child: Text('ESP32 offline - showing last known values')),
                    ],
                  ),
                ),
              _SensorCard(
                title: 'Temperature',
                value: '${repo.temperature.toStringAsFixed(1)} °C',
                icon: Icons.thermostat,
                color: Colors.orange,
                progress: repo.temperature / 50, // DHT11 range 0-50 °C
                alert: tempAlert,
                note: tempAlert
                    ? 'HIGH - above ${repo.tempLimit.toStringAsFixed(0)} °C limit'
                    : 'Normal (limit ${repo.tempLimit.toStringAsFixed(0)} °C)',
              ),
              _SensorCard(
                title: 'Humidity',
                value: '${repo.humidity.toStringAsFixed(0)} %',
                icon: Icons.water_drop,
                color: Colors.blue,
                progress: repo.humidity / 100,
                alert: false,
                note: 'Relative humidity (DHT11)',
              ),
              _SensorCard(
                title: 'MQ-2 Gas / Smoke',
                value: '${repo.gas} ADC',
                icon: Icons.cloud,
                color: Colors.deepOrange,
                progress: repo.gas / 4095,
                alert: gasAlert,
                note: gasAlert
                    ? 'HIGH - above ${repo.gasLimit} ADC limit'
                    : 'Normal (limit ${repo.gasLimit} ADC)',
              ),
              _SensorCard(
                title: 'LDR Light Level',
                value: '${repo.ldr} ADC',
                icon: Icons.wb_sunny,
                color: Colors.amber[800]!,
                progress: repo.ldr / 4095,
                alert: false,
                note: 'Raw ambient light reading (0 - 4095)',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SensorCard extends StatelessWidget {
  const _SensorCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.progress,
    required this.alert,
    required this.note,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double progress;
  final bool alert;
  final String note;

  @override
  Widget build(BuildContext context) {
    final shown = alert ? Colors.red : color;
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: alert ? const BorderSide(color: Colors.red, width: 1.5) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: shown, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                ),
                Text(value,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: shown)),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              color: shown,
              backgroundColor: shown.withOpacity(0.15),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (alert) const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                if (alert) const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    note,
                    style: TextStyle(
                      fontSize: 12,
                      color: alert ? Colors.red : Colors.grey[700],
                      fontWeight: alert ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}