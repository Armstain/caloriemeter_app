/// History tab: weekly averages + weight trend with a hand-drawn sparkline.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/lang.dart';
import '../data/app_db.dart';
import '../state/providers.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  bool _week = true;

  @override
  Widget build(BuildContext context) {
    final lang = Lang.of(context);
    final days = _week ? 7 : 30;
    final since = AppDb.todayKey(DateTime.now().subtract(Duration(days: days - 1)));
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.t('history.title')),
        actions: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, label: Text(lang.t('history.week'))),
              ButtonSegment(value: false, label: Text(lang.t('history.month'))),
            ],
            selected: {_week},
            onSelectionChanged: (s) => setState(() => _week = s.first),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder(
            future: _averages(since),
            builder: (context, snap) {
              final d = snap.data;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat(lang.t('history.avgCalories'),
                          d == null ? '—' : lang.num(d.$1.round())),
                      _stat(lang.t('history.avgProtein'),
                          d == null ? '—' : '${lang.num(d.$2.round())}g'),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _WeightCard(lang: lang),
        ],
      ),
    );
  }

  Future<(double, double)> _averages(String since) async {
    final entries = await AppDb.entriesSince(since);
    if (entries.isEmpty) return (0, 0);
    final byDay = <String>{for (final e in entries) e.date}.length;
    final kcal = entries.fold(0.0, (s, e) => s + e.totalCalories) / byDay;
    final pro =
        entries.fold(0.0, (s, e) => s + e.totalMacros.protein) / byDay;
    return (kcal, pro);
  }

  Widget _stat(String label, String value) => Column(
        children: [
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      );
}

class _WeightCard extends StatefulWidget {
  final Lang lang;
  const _WeightCard({required this.lang});

  @override
  State<_WeightCard> createState() => _WeightCardState();
}

class _WeightCardState extends State<_WeightCard> {
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final since = AppDb.todayKey(DateTime.now().subtract(const Duration(days: 90)));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lang.t('history.weight'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: AppDb.weightHistory(since),
              builder: (context, snap) {
                final rows = snap.data ?? [];
                final points =
                    rows.map((r) => (r['weight_kg'] as num).toDouble()).toList();
                if (points.length < 2) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                        child: Text(lang.t('history.logWeight'),
                            style: const TextStyle(color: Colors.grey))),
                  );
                }
                return SizedBox(height: 120, child: _Sparkline(points: points));
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: lang.t('history.weightKg'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final v = double.tryParse(_ctrl.text);
                    if (v == null || v <= 0) return;
                    await AppDb.logWeight(AppDb.todayKey(), v);
                    _ctrl.clear();
                    setState(() {});
                  },
                  child: Text(lang.t('common.save')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimal sparkline, no chart dependency.
class _Sparkline extends StatelessWidget {
  final List<double> points;
  const _Sparkline({required this.points});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _SparkPainter(points, Theme.of(context).colorScheme.primary));
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> points;
  final Color color;
  _SparkPainter(this.points, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final min = points.reduce((a, b) => a < b ? a : b);
    final max = points.reduce((a, b) => a > b ? a : b);
    final span = (max - min) == 0 ? 1.0 : (max - min);
    final dx = size.width / (points.length - 1);
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = i * dx;
      final y = size.height - ((points[i] - min) / span) * (size.height - 8) - 4;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke);
    final last = Offset(size.width, size.height - ((points.last - min) / span) * (size.height - 8) - 4);
    canvas.drawCircle(last, 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.points != points;
}
