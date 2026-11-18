import 'package:flutter/material.dart';

import 'lab_repository.dart';

class ActuatorPage extends StatelessWidget {
  const ActuatorPage({super.key});

  Future<void> _send(BuildContext context, Future<bool> action) async {
    final ok = await action;
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send command. Check your connection.')),
      );
    }
  }

  Future<void> _toggleAuto(BuildContext context, LabRepository repo, bool value) async {
    if (!value) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Disable automatic safety?'),
          content: const Text(
              'The warning light and buzzer will no longer switch on by themselves when a hazard is detected.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Disable')),
          ],
        ),
      );
      if (confirm != true) return;
    }
    if (context.mounted) await _send(context, repo.setAutoSafety(value));
  }

  @override
  Widget build(BuildContext context) {
    final repo = LabRepository.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Actuator Control')),
      body: ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final relayForced = repo.relayOn && !repo.relayCmd;
          final buzzerForced = repo.buzzerOn && !repo.buzzerCmd;

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
                      Expanded(
                          child: Text('ESP32 offline - commands will apply when it reconnects')),
                    ],
                  ),
                ),
              if (repo.autoOverride)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_rounded, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Automatic safety response active: ${repo.hazardReason}',
                          style: const TextStyle(
                              color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: SwitchListTile(
                  secondary: CircleAvatar(
                    backgroundColor: (repo.autoSafety ? Colors.green : Colors.orange).withOpacity(0.2),
                    child: Icon(Icons.shield,
                        color: repo.autoSafety ? Colors.green : Colors.orange),
                  ),
                  title: const Text('Automatic Safety Response',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text(
                      'ESP32 switches on the light and buzzer by itself when gas/smoke or temperature is too high.'),
                  value: repo.autoSafety,
                  onChanged: (v) => _toggleAuto(context, repo, v),
                ),
              ),
              Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: SwitchListTile(
                  secondary: CircleAvatar(
                    backgroundColor:
                    (repo.relayOn ? Colors.green : Colors.grey).withOpacity(0.2),
                    child: Icon(Icons.lightbulb,
                        color: repo.relayOn ? Colors.green : Colors.grey),
                  ),
                  title: const Text('Lab Warning Light / Relay',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(relayForced
                      ? 'Output: ON (forced by automatic safety)'
                      : (repo.relayOn ? 'Output: ON' : 'Output: OFF')),
                  value: repo.relayCmd,
                  onChanged: (v) => _send(context, repo.setRelay(v)),
                ),
              ),
              Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: SwitchListTile(
                  secondary: CircleAvatar(
                    backgroundColor:
                    (repo.buzzerOn ? Colors.red : Colors.grey).withOpacity(0.2),
                    child: Icon(Icons.alarm,
                        color: repo.buzzerOn ? Colors.red : Colors.grey),
                  ),
                  title: const Text('Safety Buzzer Alarm',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(buzzerForced
                      ? 'Output: ACTIVE (forced by automatic safety)'
                      : (repo.buzzerOn ? 'Output: ACTIVE' : 'Output: MUTED')),
                  value: repo.buzzerCmd,
                  onChanged: (v) => _send(context, repo.setBuzzer(v)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}