/// Riverpod providers: settings, today's entries, prices, food DB.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/app_db.dart';
import '../data/food_db.dart';
import '../data/models.dart';
import '../data/prices.dart';
import '../services/settings.dart';

final settingsProvider = StateProvider<Settings?>((_) => null);
final localeProvider = StateProvider<String>((_) => 'en');

/// Today's entries, refreshed by invalidating.
final todayEntriesProvider = FutureProvider<List<FoodEntry>>((ref) async {
  return AppDb.entriesForDay(AppDb.todayKey());
});

final todayTotalsProvider = FutureProvider<({double kcal, Macros macros})>((ref) async {
  final entries = await ref.watch(todayEntriesProvider.future);
  double kcal = 0;
  var macros = const Macros();
  for (final e in entries) {
    kcal += e.totalCalories;
    macros = macros + e.totalMacros;
  }
  return (kcal: kcal, macros: macros);
});

final waterProvider = FutureProvider<int>((ref) async {
  return AppDb.waterForDay(AppDb.todayKey());
});

final pricesProvider = FutureProvider<PriceData>((ref) async {
  return PriceService().load();
});

final foodDbProvider = FutureProvider<FoodDatabase>((ref) async {
  return FoodDatabase.load();
});

/// Bottom-nav tab index.
final tabProvider = StateProvider<int>((_) => 0);
