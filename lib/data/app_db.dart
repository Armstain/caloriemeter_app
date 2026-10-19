/// SQLite storage via sqflite (no codegen needed).
/// Tables: entries, weights, water, price_corrections, ai_corrections.
library;

import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../data/models.dart';
import 'workout_db.dart';

class AppDb {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'caloriemeter.db'),
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE entries(
            id TEXT PRIMARY KEY,
            timestamp TEXT NOT NULL,
            date TEXT NOT NULL,
            meal_type TEXT NOT NULL,
            foods_json TEXT NOT NULL,
            total_kcal REAL NOT NULL,
            macros_json TEXT NOT NULL,
            image_path TEXT,
            shared_meal_id TEXT,
            cooked_by TEXT,
            correction_json TEXT
          )''');
        await db.execute('CREATE INDEX idx_entries_date ON entries(date)');
        await db.execute('''
          CREATE TABLE weights(
            date TEXT PRIMARY KEY,
            weight_kg REAL NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE water(
            date TEXT PRIMARY KEY,
            ml INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE price_corrections(
            item_id TEXT PRIMARY KEY,
            price REAL NOT NULL,
            market TEXT,
            updated_at TEXT NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE ai_corrections(
            id TEXT PRIMARY KEY,
            created_at TEXT NOT NULL,
            original_json TEXT NOT NULL,
            corrected_json TEXT NOT NULL
          )''');
        await WorkoutDb.createTables(db);
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await WorkoutDb.createTables(db);
        }
      },
    );
    return _db!;
  }

  static String _day(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  // --- entries -----------------------------------------------------------

  static Future<void> saveEntry(FoodEntry e) async {
    final db = await AppDb.db;
    await db.insert(
      'entries',
      {
        'id': e.id,
        'timestamp': e.timestamp.toIso8601String(),
        'date': e.date,
        'meal_type': e.mealType,
        'foods_json': json.encode(e.foods.map((f) => f.toJson()).toList()),
        'total_kcal': e.totalCalories,
        'macros_json': json.encode(e.totalMacros.toJson()),
        'image_path': e.imagePath,
        'shared_meal_id': e.sharedMealId,
        'cooked_by': e.cookedBy,
        'correction_json': e.correction == null ? null : json.encode(e.correction),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<FoodEntry>> entriesForDay(String date) async {
    final db = await AppDb.db;
    final rows = await db.query('entries',
        where: 'date = ?', whereArgs: [date], orderBy: 'timestamp ASC');
    return rows.map(_rowToEntry).toList();
  }

  static Future<List<FoodEntry>> entriesSince(String date) async {
    final db = await AppDb.db;
    final rows = await db.query('entries',
        where: 'date >= ?', whereArgs: [date], orderBy: 'date ASC, timestamp ASC');
    return rows.map(_rowToEntry).toList();
  }

  static FoodEntry _rowToEntry(Map<String, dynamic> r) {
    final foods = (json.decode(r['foods_json'] as String) as List)
        .map((j) => AnalyzedFood.fromJson(Map<String, dynamic>.from(j as Map)))
        .toList();
    return FoodEntry(
      id: r['id'] as String,
      timestamp: DateTime.parse(r['timestamp'] as String),
      date: r['date'] as String,
      mealType: r['meal_type'] as String,
      foods: foods,
      totalCalories: (r['total_kcal'] as num).toDouble(),
      totalMacros:
          Macros.fromJson(Map<String, dynamic>.from(json.decode(r['macros_json'] as String) as Map)),
      imagePath: r['image_path'] as String?,
      sharedMealId: r['shared_meal_id'] as String?,
      cookedBy: r['cooked_by'] as String?,
      correction: r['correction_json'] == null
          ? null
          : Map<String, dynamic>.from(json.decode(r['correction_json'] as String) as Map),
    );
  }

  static Future<void> deleteEntry(String id) async {
    final db = await AppDb.db;
    await db.delete('entries', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> pruneOlderThan(String cutoffDate) async {
    final db = await AppDb.db;
    await db.delete('entries', where: 'date < ?', whereArgs: [cutoffDate]);
  }

  static Future<void> deleteAll() async {
    final db = await AppDb.db;
    for (final t in ['entries', 'weights', 'water', 'price_corrections', 'ai_corrections']) {
      await db.delete(t);
    }
  }

  // --- weights -----------------------------------------------------------

  static Future<void> logWeight(String date, double kg) async {
    final db = await AppDb.db;
    await db.insert('weights', {'date': date, 'weight_kg': kg},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Map<String, dynamic>>> weightHistory(String sinceDate) async {
    final db = await AppDb.db;
    return db.query('weights',
        where: 'date >= ?', whereArgs: [sinceDate], orderBy: 'date ASC');
  }

  // --- water -------------------------------------------------------------

  static Future<int> waterForDay(String date) async {
    final db = await AppDb.db;
    final rows =
        await db.query('water', where: 'date = ?', whereArgs: [date], limit: 1);
    if (rows.isEmpty) return 0;
    return (rows.first['ml'] as num).toInt();
  }

  static Future<int> addWater(String date, int ml) async {
    final current = await waterForDay(date);
    final db = await AppDb.db;
    await db.insert('water', {'date': date, 'ml': current + ml},
        conflictAlgorithm: ConflictAlgorithm.replace);
    return current + ml;
  }

  // --- price corrections (crowd-sourced, on-device for v1) ---------------

  static Future<void> savePriceCorrection(String itemId, double price, String? market) async {
    final db = await AppDb.db;
    await db.insert(
      'price_corrections',
      {
        'item_id': itemId,
        'price': price,
        'market': market,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Map<String, double>> priceCorrections() async {
    final db = await AppDb.db;
    final rows = await db.query('price_corrections');
    return {
      for (final r in rows) r['item_id'] as String: (r['price'] as num).toDouble()
    };
  }

  // --- AI corrections (training data for future shared-plate/voice) ------

  static Future<void> saveAiCorrection(
      String id, Map<String, dynamic> original, Map<String, dynamic> corrected) async {
    final db = await AppDb.db;
    await db.insert('ai_corrections', {
      'id': id,
      'created_at': DateTime.now().toIso8601String(),
      'original_json': json.encode(original),
      'corrected_json': json.encode(corrected),
    });
  }

  static String todayKey([DateTime? t]) => _day(t ?? DateTime.now());
}
