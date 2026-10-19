/// Active workout session: log sets, rest timer, finish & save.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/lang.dart';
import '../data/app_db.dart';
import '../data/exercises.dart';
import '../data/routines.dart';
import '../data/workout_db.dart';

class _SetRow {
  final kgCtrl = TextEditingController();
  final repsCtrl = TextEditingController();
  bool done = false;
  void dispose() {
    kgCtrl.dispose();
    repsCtrl.dispose();
  }
}

class _ExerciseState {
  final RoutineExercise plan;
  final List<_SetRow> rows = [];
  _ExerciseState(this.plan);
}

class SessionScreen extends ConsumerStatefulWidget {
  final Routine routine;
  const SessionScreen({super.key, required this.routine});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  final _exercises = <_ExerciseState>[];
  late DateTime _started;
  Timer? _clock;
  Duration _elapsed = Duration.zero;
  bool _saving = false;
  Map<String, double> _best = {};

  @override
  void initState() {
    super.initState();
    _started = DateTime.now();
    for (final b in widget.routine.blocks) {
      final st = _ExerciseState(b);
      for (var i = 0; i < b.sets; i++) {
        st.rows.add(_SetRow());
      }
      _exercises.add(st);
    }
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed = DateTime.now().difference(_started));
    });
    _prefill();
  }

  Future<void> _prefill() async {
    final last = await WorkoutDb.lastSetsByExercise();
    _best = await WorkoutDb.bestWeights();
    if (!mounted) return;
    setState(() {
      for (final st in _exercises) {
        final prev = last[st.plan.exerciseId];
        if (prev == null || prev.isEmpty) continue;
        for (var i = 0; i < st.rows.length; i++) {
          final p = prev[i % prev.length];
          st.rows[i].kgCtrl.text = _fmtKg(p.weightKg);
          st.rows[i].repsCtrl.text = p.reps.toString();
        }
      }
    });
  }

  String _fmtKg(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  @override
  void dispose() {
    _clock?.cancel();
    for (final st in _exercises) {
      for (final r in st.rows) {
        r.dispose();
      }
    }
    super.dispose();
  }

  String _clockText() {
    final h = _elapsed.inHours;
    final m = _elapsed.inMinutes % 60;
    final s = _elapsed.inSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final lang = Lang.of(context);
    final name = lang.locale == 'bn' ? widget.routine.nameBn : widget.routine.nameEn;
    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          Center(
              child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(_clockText(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)))),
          IconButton(
            icon: const Icon(Icons.timer_outlined),
            tooltip: lang.t('workout.restTimer'),
            onPressed: () => _showRestTimer(context),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _exercises.length + 1,
        itemBuilder: (context, i) {
          if (i == _exercises.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _finish,
                  child: Text(lang.t('workout.finish')),
                ),
              ),
            );
          }
          return _exerciseCard(_exercises[i], lang);
        },
      ),
    );
  }

  Widget _exerciseCard(_ExerciseState st, Lang lang) {
    final ex = exerciseById[st.plan.exerciseId]!;
    final name = lang.locale == 'bn' ? ex.nameBn : ex.nameEn;
    final best = _best[ex.id];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                if (best != null && best > 0)
                  Chip(
                    label: Text('PR ${_fmtKg(best)}kg',
                        style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${lang.t('workout.target')}: ${st.plan.sets} × ${st.plan.reps}'
              '${_cue(ex, lang)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Table(
              columnWidths: const {
                0: FixedColumnWidth(36),
                1: FlexColumnWidth(),
                2: FlexColumnWidth(),
                3: FixedColumnWidth(48),
              },
              children: [
                TableRow(children: [
                  _th('#'),
                  _th('kg'),
                  _th(lang.t('workout.reps')),
                  _th('✓'),
                ]),
                for (var i = 0; i < st.rows.length; i++)
                  TableRow(children: [
                    Center(
                        child: Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Text('${i + 1}'))),
                    _numCell(st.rows[i].kgCtrl, st.rows[i]),
                    _numCell(st.rows[i].repsCtrl, st.rows[i]),
                    Checkbox(
                      value: st.rows[i].done,
                      onChanged: (v) =>
                          setState(() => st.rows[i].done = v ?? false),
                    ),
                  ]),
              ],
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text(lang.t('workout.addSet')),
              onPressed: () => setState(() => st.rows.add(_SetRow())),
            ),
          ],
        ),
      ),
    );
  }

  String _cue(Exercise ex, Lang lang) {
    final cue = lang.locale == 'bn' ? ex.cueBn : ex.cueEn;
    return ' · $cue';
  }

  Widget _th(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(s,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center),
      );

  Widget _numCell(TextEditingController ctrl, _SetRow row) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(vertical: 8),
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
      );

  void _showRestTimer(BuildContext context) {
    final lang = Lang.of(context);
    showModalBottomSheet(
      context: context,
      builder: (_) => _RestTimerSheet(lang: lang),
    );
  }

  Future<void> _finish() async {
    final lang = Lang.of(context);
    setState(() => _saving = true);
    try {
      final sets = <WorkoutSet>[];
      final sessionMax = <String, double>{};
      for (final st in _exercises) {
        var n = 0;
        for (final r in st.rows) {
          if (!r.done) continue;
          final kg = double.tryParse(r.kgCtrl.text) ?? 0;
          final reps = int.tryParse(r.repsCtrl.text) ?? 0;
          if (kg <= 0 || reps <= 0) continue;
          n++;
          sets.add(WorkoutSet(
              exerciseId: st.plan.exerciseId, setNo: n, weightKg: kg, reps: reps));
          final prev = sessionMax[st.plan.exerciseId] ?? 0;
          if (kg > prev) sessionMax[st.plan.exerciseId] = kg;
        }
      }
      if (sets.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(lang.t('workout.noSets'))));
        }
        return;
      }
      final volume = sets.fold(0.0, (s, x) => s + x.weightKg * x.reps);
      final now = DateTime.now();
      final name = lang.locale == 'bn' ? widget.routine.nameBn : widget.routine.nameEn;
      final session = WorkoutSession(
        id: 'w${now.millisecondsSinceEpoch}',
        date: AppDb.todayKey(now),
        routineId: widget.routine.id,
        routineName: name,
        startedAt: _started.toIso8601String(),
        endedAt: now.toIso8601String(),
        durationMin: _elapsed.inMinutes,
        volumeKg: volume,
        sets: sets,
      );
      await WorkoutDb.saveSession(session);

      final prs = <String>[];
      sessionMax.forEach((id, max) {
        final prev = _best[id] ?? 0;
        if (prev > 0 && max > prev) {
          final ex = exerciseById[id]!;
          prs.add('${lang.locale == 'bn' ? ex.nameBn : ex.nameEn} ${_fmtKg(max)}kg');
        }
      });

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(lang.t('workout.done')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${lang.t('workout.volume')}: ${volume.toStringAsFixed(0)} kg'),
              Text(
                  '${lang.t('workout.duration')}: ${_elapsed.inMinutes} ${lang.t('workout.min')}'),
              Text('${lang.t('workout.setsDone')}: ${sets.length}'),
              if (prs.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('🏆 ${lang.t('workout.newPRs')}:',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                for (final p in prs) Text('• $p'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text(lang.t('common.ok')),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _RestTimerSheet extends StatefulWidget {
  final Lang lang;
  const _RestTimerSheet({required this.lang});

  @override
  State<_RestTimerSheet> createState() => _RestTimerSheetState();
}

class _RestTimerSheetState extends State<_RestTimerSheet> {
  static const _presets = [60, 90, 120, 180];
  int _total = 90;
  int _left = 90;
  Timer? _timer;
  bool _running = false;

  void _start(int secs) {
    _timer?.cancel();
    setState(() {
      _total = secs;
      _left = secs;
      _running = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _left--;
        if (_left <= 0) {
          _running = false;
          t.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final mm = (_left ~/ 60).toString().padLeft(2, '0');
    final ss = (_left % 60).toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(lang.t('workout.restTimer'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: _total == 0 ? 0 : _left / _total,
                  strokeWidth: 10,
                ),
                Text('$mm:$ss',
                    style: const TextStyle(
                        fontSize: 32, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final p in _presets)
                ChoiceChip(
                  label: Text('${p}s'),
                  selected: _total == p,
                  onSelected: (_) => _start(p),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: _running
                    ? () {
                        _timer?.cancel();
                        setState(() => _running = false);
                      }
                    : null,
                child: Text(lang.t('common.cancel')),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _running ? null : () => _start(_total),
                child: Text(lang.t('workout.startRest')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
