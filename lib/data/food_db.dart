/// Local food database: loads assets/food_db.json, bilingual search.
library;

import 'dart:convert';
import 'package:flutter/services.dart';
import 'models.dart';

class FoodDatabase {
  final List<DbFood> foods;
  FoodDatabase(this.foods);

  static FoodDatabase? _instance;
  static Future<FoodDatabase> load() async {
    if (_instance != null) return _instance!;
    final raw = await rootBundle.loadString('assets/food_db.json');
    final list = (json.decode(raw) as List)
        .map((j) => DbFood.fromJson(Map<String, dynamic>.from(j as Map)))
        .toList();
    _instance = FoodDatabase(list);
    return _instance!;
  }

  /// Simple ranked search across English + Bangla + aliases.
  List<DbFood> search(String query, {int limit = 30}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return foods.take(limit).toList();
    final scored = <DbFood, int>{};
    for (final f in foods) {
      final text = f.searchText;
      int score = -1;
      if (f.nameEn.toLowerCase().startsWith(q) || f.nameBn.startsWith(query.trim())) {
        score = 0;
      } else if (text.contains(q)) {
        score = 1;
      } else {
        // token match: every query word appears somewhere
        final words = q.split(RegExp(r'\s+'));
        if (words.every(text.contains)) score = 2;
      }
      if (score >= 0) scored[f] = score;
    }
    final sorted = scored.keys.toList()
      ..sort((a, b) => scored[a]!.compareTo(scored[b]!));
    return sorted.take(limit).toList();
  }

  DbFood? byId(String id) {
    for (final f in foods) {
      if (f.id == id) return f;
    }
    return null;
  }
}
