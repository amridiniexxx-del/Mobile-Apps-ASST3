import 'dart:math' as math;

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'lab_repository.dart';

enum _Metric { temperature, humidity, gas, ldr }

double _num(Object? v) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0.0;
}

String _pad(int n) => n.toString().padLeft(2, '0');

String _fmtTime(DateTime? t) {
  if (t == null) return 'Time unavailable';
  return '${_pad(t.day)}/${_pad(t.month)} ${_pad(t.hour)}:${_pad(t.minute)}:${_pad(t.second)}';
}

class _LogEntry {
  _LogEntry({
    required this.event,
    required this.time,
    required this.temperature,
    required this.humidity,
    required this.gas,
    required this.ldr,
  });

  final String event;
  final DateTime? time;
  final double temperature;
  final double humidity;
  final double gas;
  final double ldr;

  bool get isHazard => event.toUpperCase().startsWith('HAZARD');

  factory _LogEntry.fromMap(Map<dynamic, dynamic> m) {
    final epoch = _num(m['epoch']).toInt();
    return _LogEntry(
      event: (m['event'] ?? 'Periodic log').toString(),
      time: epoch > 1000000000
          ? DateTime.fromMillisecondsSinceEpoch(epoch * 1000)
          : null,
      temperature: _num(m['temperature']),
      humidity: _num(m['humidity']),
      gas: _num(m['gas']),
      ldr: _num(m['ldr']),
    );
  }

  double valueOf(_Metric m) {
    switch (m) {
      case _Metric.temperature:
        return temperature;
      case _Metric.humidity:
        return humidity;
      case _Metric.gas:
        return gas;
      case _Metric.ldr:
        return ldr;
    }
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final LabRepository _repo = LabRepository.instance;
  late final Stream<DatabaseEvent> _stream = _repo.historyStream(limit: 40);
  _Metric _metric = _Metric.temperature;

  String get _unit {
    switch (_metric) {
      case _Metric.temperature:
        return '°C';
      case _Metric.humidity:
        return '%';
      case _Metric.gas:
      case _Metric.ldr:
        return 'ADC';
    }
  }

  Color get _color {
    switch (_metric) {
      case _Metric.temperature:
        return Colors.orange;
      case _Metric.humidity:
        return Colors.blue;
      case _Metric.gas:
        return Colors.deepOrange;
      case _Metric.ldr:
        return Colors.amber.shade800;
    }
  }

  double? get _limit {
    switch (_metric) {
      case _Metric.temperature:
        return _repo.tempLimit;
      case _Metric.gas:
        return _repo.gasLimit.toDouble();
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historical Logs')),
      body: StreamBuilder<DatabaseEvent>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load history.'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final raw = snapshot.data?.snapshot.value;
          if (raw is! Map || raw.isEmpty) {
            return const Center(
              child: Text(
                'No historical logs recorded yet.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          // Push IDs are chronological, so sorting keys sorts by time.
          final keys = raw.keys.map((k) => k.toString()).toList()..sort();
          final logs = <_LogEntry>[];
          for (final k in keys) {
            final v = raw[k];
            if (v is Map) logs.add(_LogEntry.fromMap(v));
          }
          if (logs.isEmpty) {
            return const Center(child: Text('No historical logs recorded yet.'));
          }

          final values = logs.map((l) => l.valueOf(_metric)).toList();
          final minV = values.reduce(math.min);
          final maxV = values.reduce(math.max);
          final avgV = values.reduce((a, b) => a + b) / values.length;
          final hazardCount = logs.where((l) => l.isHazard).length;
          final newestFirst = logs.reversed.toList();

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<_Metric>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: _Metric.temperature, label: Text('Temp')),
                    ButtonSegment(value: _Metric.humidity, label: Text('Hum')),
                    ButtonSegment(value: _Metric.gas, label: Text('Gas')),
                    ButtonSegment(value: _Metric.ldr, label: Text('Light')),
                  ],
                  selected: {_metric},
                  onSelectionChanged: (s) => setState(() => _metric = s.first),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 8),
                        child: Text(
                          'Last ${logs.length} readings ($_unit)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(
                        height: 200,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _LineChartPainter(
                            values: values,
                            color: _color,
                            limit: _limit,
                            textColor: Colors.grey.shade700,
                            gridColor: Colors.grey.withOpacity(0.25),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 40, top: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_fmtTime(logs.first.time),
                                style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            Text(_fmtTime(logs.last.time),
                                style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _StatChip(label: 'Min', value: minV.toStringAsFixed(1), color: Colors.blue),
                  _StatChip(label: 'Avg', value: avgV.toStringAsFixed(1), color: Colors.green),
                  _StatChip(label: 'Max', value: maxV.toStringAsFixed(1), color: Colors.red),
                  _StatChip(
                    label: 'Hazards',
                    value: '$hazardCount',
                    color: hazardCount > 0 ? Colors.red : Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Event Log (newest first)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              for (final log in newestFirst)
                Card(
                  elevation: 1,
                  color: log.isHazard ? Colors.red.withOpacity(0.08) : null,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      log.isHazard ? Icons.warning_rounded : Icons.history_rounded,
                      color: log.isHazard ? Colors.red : Colors.blue,
                    ),
                    title: Text(
                      log.event,
                      style: TextStyle(
                        fontWeight: log.isHazard ? FontWeight.bold : FontWeight.normal,
                        color: log.isHazard ? Colors.red : null,
                      ),
                    ),
                    subtitle: Text(
                      '${_fmtTime(log.time)}\n'
                          'T ${log.temperature.toStringAsFixed(1)}°C  '
                          'H ${log.humidity.toStringAsFixed(0)}%  '
                          'Gas ${log.gas.toInt()}  LDR ${log.ldr.toInt()}',
                    ),
                    isThreeLine: true,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple dependency-free line chart (no extra packages needed).
class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.values,
    required this.color,
    required this.limit,
    required this.textColor,
    required this.gridColor,
  });

  final List<double> values;
  final Color color;
  final double? limit;
  final Color textColor;
  final Color gridColor;

  void _label(Canvas canvas, String text, Offset offset) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: 10, color: textColor)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset - Offset(tp.width + 6, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    const left = 44.0;
    const pad = 8.0;
    final chart = Rect.fromLTRB(left, pad, size.width - pad, size.height - pad);

    double minV = values.reduce(math.min);
    double maxV = values.reduce(math.max);
    if (limit != null) {
      maxV = math.max(maxV, limit!);
      minV = math.min(minV, limit!);
    }
    if (maxV - minV < 1) {
      maxV += 1;
      minV -= 1;
    }
    final margin = (maxV - minV) * 0.1;
    maxV += margin;
    minV -= margin;
    final range = maxV - minV;

    double yOf(double v) => chart.bottom - (v - minV) / range * chart.height;
    double xOf(int i) => values.length == 1
        ? chart.center.dx
        : chart.left + chart.width * i / (values.length - 1);

    // Grid + y labels
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = chart.top + chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      _label(canvas, (maxV - range * i / 3).toStringAsFixed(0), Offset(chart.left, y));
    }

    // Limit line (dashed red)
    if (limit != null) {
      final y = yOf(limit!);
      final dash = Paint()
        ..color = Colors.red
        ..strokeWidth = 1.5;
      for (double x = chart.left; x < chart.right; x += 10) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 5, chart.right), y), dash);
      }
    }

    // Data line
    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final p = Offset(xOf(i), yOf(values[i]));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );

    // Points (red if above limit)
    for (int i = 0; i < values.length; i++) {
      final over = limit != null && values[i] > limit!;
      canvas.drawCircle(
        Offset(xOf(i), yOf(values[i])),
        over ? 4 : 3,
        Paint()..color = over ? Colors.red : color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.values != values || old.color != color || old.limit != limit;
}