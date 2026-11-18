import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

const String kDatabaseUrl =
    'https://smart-monitor-asst3-default-rtdb.asia-southeast1.firebasedatabase.app/';

double _toDouble(Object? v, double fallback) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? fallback;
}

int _toInt(Object? v, int fallback) {
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? fallback;
}

bool _toBool(Object? v, bool fallback) {
  if (v == null) return fallback;
  return v == true || v == 1 || v == 'true' || v == '1';
}

/// Single place that talks to Firebase for live data.
/// Pages listen to this object instead of each opening their own streams,
/// so nothing leaks when the user switches tabs.
class LabRepository extends ChangeNotifier {
  LabRepository._();
  static final LabRepository instance = LabRepository._();

  final DatabaseReference _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: kDatabaseUrl,
  ).ref();

  // --- Sensors (/Sensors)
  double temperature = 0;
  double humidity = 0;
  int gas = 0;
  int ldr = 0;

  // --- Actual actuator output states reported by the ESP32 (/Actuators)
  bool relayOn = false;
  bool buzzerOn = false;

  // --- Commands sent by the app (/Control)
  bool relayCmd = false;
  bool buzzerCmd = false;
  bool autoSafety = true;

  // --- Device / safety status (/Status)
  bool hazard = false;
  String hazardReason = '';
  bool autoOverride = false;
  int gasLimit = 1500;
  double tempLimit = 35;
  int wifiRssi = 0;

  bool deviceOnline = false;
  DateTime? lastSeen;

  final List<StreamSubscription<DatabaseEvent>> _subs = [];
  Timer? _watchdog;
  bool _started = false;
  int _lastHeartbeat = -1;
  static const Duration _offlineAfter = Duration(seconds: 12);

  void start() {
    if (_started) return;
    _started = true;

    _listen('Sensors', (m) {
      temperature = _toDouble(m['temperature'], temperature);
      humidity = _toDouble(m['humidity'], humidity);
      gas = _toInt(m['gas'], gas);
      ldr = _toInt(m['ldr'], ldr);
    });

    _listen('Actuators', (m) {
      relayOn = _toBool(m['relay'], relayOn);
      buzzerOn = _toBool(m['buzzer'], buzzerOn);
    });

    _listen('Control', (m) {
      relayCmd = _toBool(m['relay'], relayCmd);
      buzzerCmd = _toBool(m['buzzer'], buzzerCmd);
      autoSafety = _toBool(m['autoSafety'], autoSafety);
    });

    _listen('Status', (m) {
      hazard = _toBool(m['hazard'], hazard);
      hazardReason = (m['reason'] ?? '').toString();
      autoOverride = _toBool(m['override'], autoOverride);
      gasLimit = _toInt(m['gasLimit'], gasLimit);
      tempLimit = _toDouble(m['tempLimit'], tempLimit);
      wifiRssi = _toInt(m['wifiRssi'], wifiRssi);

      // The ESP32 bumps "heartbeat" every ~2 s. A changing value = device alive.
      final hb = _toInt(m['heartbeat'], -1);
      if (hb != _lastHeartbeat) {
        if (_lastHeartbeat != -1) lastSeen = DateTime.now();
        _lastHeartbeat = hb;
      }
      deviceOnline = _computeOnline();
    });

    _watchdog = Timer.periodic(const Duration(seconds: 3), (_) {
      final online = _computeOnline();
      if (online != deviceOnline) {
        deviceOnline = online;
        notifyListeners();
      }
    });
  }

  void stop() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _watchdog?.cancel();
    _watchdog = null;
    _started = false;
    _lastHeartbeat = -1;
    lastSeen = null;
    deviceOnline = false;
  }

  bool _computeOnline() {
    final seen = lastSeen;
    return seen != null && DateTime.now().difference(seen) < _offlineAfter;
  }

  void _listen(String path, void Function(Map<dynamic, dynamic> m) onMap) {
    _subs.add(
      _db.child(path).onValue.listen(
            (event) {
          final v = event.snapshot.value;
          if (v is Map) {
            onMap(v);
            notifyListeners();
          }
        },
        onError: (Object e) => debugPrint('Firebase "$path" error: $e'),
      ),
    );
  }

  // ----------------------------------------------------------- Commands
  Future<bool> setRelay(bool value) {
    relayCmd = value;
    notifyListeners();
    return _write('Control/relay', value);
  }

  Future<bool> setBuzzer(bool value) {
    buzzerCmd = value;
    notifyListeners();
    return _write('Control/buzzer', value);
  }

  Future<bool> setAutoSafety(bool value) {
    autoSafety = value;
    notifyListeners();
    return _write('Control/autoSafety', value);
  }

  Future<bool> _write(String path, Object value) async {
    try {
      await _db.child(path).set(value);
      return true;
    } catch (e) {
      debugPrint('Firebase write "$path" failed: $e');
      return false;
    }
  }

  // ------------------------------------------------------------ History
  Stream<DatabaseEvent> historyStream({int limit = 40}) =>
      _db.child('History').limitToLast(limit).onValue;
}