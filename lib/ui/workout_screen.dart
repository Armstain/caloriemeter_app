/// Workout tab: start sessions, browse routines, plate calculator, history.
library;

import 'package:flutter/material.dart';
import '../core/lang.dart';
import '../data/routines.dart';
import '../data/workout_db.dart';
import 'plate_calc.dart';
import 'session_screen.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  ({int sessions, double volume})? _week;
  List<WorkoutSession> _recent = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final week = await WorkoutDb.weekStats();
    final recent = await WorkoutDb.recentSessions(limit: 10);
    if (mounted) setState(() {
      _week = week;
      _recent = recent;
    });
  }

  Future<void> _startFlow() async {
    final lang = Lang.of(context);
    final routine = await showModalBottomSheet<Routine>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(lang.t('workout.pickRoutine'),
                  style: Theme.of(c).textTheme.titleLarge),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final r in routines)
                    ListTile(
                      title: Text(lang.locale == 'bn' ? r.nameBn : r.nameEn),
                      subtitle: Text(
                          '${lang.locale == 'bn' ? r.daysBn : r.daysEn} · ${r.blocks.length} ${lang.t('workout.exercises')}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(c, r),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (routine != null && mounted) {
      final done = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => SessionScreen(routine: routine)),
      );
      if (done == true) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Lang.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.t('workout.title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: lang.t('workout.plateCalc'),
            onPressed: () => showPlateCalculator(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_week != null)
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat(lang.t('workout.thisWeek'),
                        lang.num(_week!.sessions)),
                    _stat(lang.t('workout.volume'),
                        '${lang.num(_week!.volume.round())} kg'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: Text(lang.t('workout.start')),
              onPressed: _startFlow,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
          const SizedBox(height: 16),
          Text(lang.t('workout.routines'),
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...routines.map((r) => _routineCard(r, lang)),
          const SizedBox(height: 16),
          if (_recent.isNotEmpty) ...[
            Text(lang.t('workout.recent'),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ..._recent.map((s) => _sessionTile(s, lang)),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
        children: [
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );

  Widget _routineCard(Routine r, Lang lang) {
    final name = lang.locale == 'bn' ? r.nameBn : r.nameEn;
    final desc = lang.locale == 'bn' ? r.descBn : r.descEn;
    final days = lang.locale == 'bn' ? r.daysBn : r.daysEn;
    return Card(
      child: ListTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$desc\n$days · ${r.blocks.length} ${lang.t('workout.exercises')}'),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.play_circle_outline),
          onPressed: () async {
            final done = await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => SessionScreen(routine: r)),
            );
            if (done == true) _load();
          },
        ),
      ),
    );
  }

  Widget _sessionTile(WorkoutSession s, Lang lang) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.fitness_center_outlined),
        title: Text(s.routineName),
        subtitle: Text(
            '${s.date} · ${s.durationMin ?? 0} ${lang.t('workout.min')}'),
        trailing: Text('${s.volumeKg.toStringAsFixed(0)} kg',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
