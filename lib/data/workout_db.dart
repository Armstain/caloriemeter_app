/// Workout storage: sessions + logged sets. Tables are created by AppDb
/// (v2 migration); this file holds the queries.
library;

import 'package:sqflite/sqflite.dart';
import 'app_db.dart';

class WorkoutSet {
  final String exerciseId;
  final int setNo;
  final double weightKg;
  final int reps;
  const WorkoutSet({
    required this.exerciseId,
    required this.setNo,
    required this.weightKg,
    required this.reps,
  });
}

class WorkoutSession {
  final String id;
  final String date;
  final String routineId;
  final String routineName;
  final String startedAt;
  final String? endedAt;
  final int? durationMin;
  final double volumeKg;
  final List<WorkoutSet> sets;
  const WorkoutSession({
    required this.id,
    required this.date,
    required this.routineId,
    required this.routineName,
    required this.startedAt,
    this.endedAt,
    this.durationMin,
    required this.volumeKg,
    this.sets = const [],
  });
}

class WorkoutDb {
  static Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout_sessions(
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        routine_id TEXT NOT NULL,
        routine_name TEXT NOT NULL,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        duration_min INTEGER,
        volume_kg REAL NOT NULL DEFAULT 0
      )''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_wsessions_date ON workout_sessions(date)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout_sets(
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        exercise_id TEXT NOT NULL,
        set_no INTEGER NOT NULL,
        weight_kg REAL NOT NULL,
        reps INTEGER NOT NULL
      )''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_wsets_session ON workout_sets(session_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_wsets_exercise ON workout_sets(exercise_id)');
  }

  static Future<void> saveSession(WorkoutSession s) async {
    final db = await AppDb.db;
    await db.insert(
        'workout_sessions',
        {
          'id': s.id,
          'date': s.date,
          'routine_id': s.routineId,
          'routine_name': s.routineName,
          'started_at': s.startedAt,
          'ended_at': s.endedAt,
          'duration_min': s.durationMin,
          'volume_kg': s.volumeKg,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
    final batch = db.batch();
    var i = 0;
    for (final set in s.sets) {
      batch.insert('workout_sets', {
        'id': '${s.id}_$i',
        'session_id': s.id,
        'exercise_id': set.exerciseId,
        'set_no': set.setNo,
        'weight_kg': set.weightKg,
        'reps': set.reps,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      i++;
    }
    await batch.commit(noResult: true);
  }

  static Future<List<WorkoutSession>> recentSessions({int limit = 20}) async {
    final db = await AppDb.db;
    final rows = await db.query('workout_sessions',
        orderBy: 'started_at DESC', limit: limit);
    return [
      for (final r in rows)
        WorkoutSession(
          id: r['id'] as String,
          date: r['date'] as String,
          routineId: r['routine_id'] as String,
          routineName: r['routine_name'] as String,
          startedAt: r['started_at'] as String,
          endedAt: r['ended_at'] as String?,
          durationMin: r['duration_min'] as int?,
          volumeKg: (r['volume_kg'] as num).toDouble(),
        )
    ];
  }

  /// Best (max weight) ever logged per exercise, for PR detection + prefill.
  static Future<Map<String, double>> bestWeights() async {
    final db = await AppDb.db;
    final rows = await db.rawQuery(
        'SELECT exercise_id, MAX(weight_kg) AS best FROM workout_sets GROUP BY exercise_id');
    return {
      for (final r in rows) r['exercise_id'] as String: (r['best'] as num).toDouble()
    };
  }

  /// Last logged sets per exercise (for prefilling today's numbers).
  static Future<Map<String, List<WorkoutSet>>> lastSetsByExercise() async {
    final db = await AppDb.db;
    final rows = await db.rawQuery('''
      SELECT ws.* FROM workout_sets ws
      JOIN workout_sessions s ON s.id = ws.session_id
      WHERE s.started_at = (
        SELECT MAX(s2.started_at) FROM workout_sessions s2
        JOIN workout_sets ws2 ON ws2.session_id = s2.id
        WHERE ws2.exercise_id = ws.exercise_id
      )
      ORDER BY ws.set_no
    ''');
    final map = <String, List<WorkoutSet>>{};
    for (final r in rows) {
      final id = r['exercise_id'] as String;
      (map[id] ??= []).add(WorkoutSet(
        exerciseId: id,
        setNo: r['set_no'] as int,
        weightKg: (r['weight_kg'] as num).toDouble(),
        reps: r['reps'] as int,
      ));
    }
    return map;
  }

  static Future<({int sessions, double volume})> weekStats() async {
    final db = await AppDb.db;
    final since = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    final rows = await db.rawQuery(
        'SELECT COUNT(*) AS n, COALESCE(SUM(volume_kg),0) AS v FROM workout_sessions WHERE started_at >= ?',
        [since]);
    final r = rows.first;
    return (
      sessions: r['n'] as int,
      volume: (r['v'] as num).toDouble(),
    );
  }
}
