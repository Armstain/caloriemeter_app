/// On-device settings: SharedPreferences for prefs, secure storage for the key.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/nutrition.dart';

class Settings {
  static const _onboarded = 'onboarded';
  static const _locale = 'locale';
  static const _goalPath = 'goal_path';
  static const _phase = 'phase';
  static const _sex = 'sex';
  static const _age = 'age';
  static const _heightCm = 'height_cm';
  static const _weightKg = 'weight_kg';
  static const _activity = 'activity';
  static const _calorieGoal = 'calorie_goal';
  static const _proteinGoal = 'protein_goal';
  static const _ramadan = 'ramadan';
  static const _retentionDays = 'retention_days';
  static const _apiKeyKey = 'gemini_api_key';

  final SharedPreferences prefs;
  final FlutterSecureStorage secure;

  Settings(this.prefs, this.secure);

  bool get onboarded => prefs.getBool(_onboarded) ?? false;
  Future<void> setOnboarded(bool v) => prefs.setBool(_onboarded, v);

  String get locale => prefs.getString(_locale) ?? 'en';
  Future<void> setLocale(String v) => prefs.setString(_locale, v);

  GoalPath get goalPath =>
      GoalPath.values.asNameMap()[prefs.getString(_goalPath)] ?? GoalPath.general;
  Future<void> setGoalPath(GoalPath v) => prefs.setString(_goalPath, v.name);

  GymPhase get phase =>
      GymPhase.values.asNameMap()[prefs.getString(_phase)] ?? GymPhase.maintain;
  Future<void> setPhase(GymPhase v) => prefs.setString(_phase, v.name);

  Sex get sex => Sex.values.asNameMap()[prefs.getString(_sex)] ?? Sex.male;
  Future<void> setSex(Sex v) => prefs.setString(_sex, v.name);

  int get age => prefs.getInt(_age) ?? 25;
  Future<void> setAge(int v) => prefs.setInt(_age, v);

  double get heightCm => prefs.getDouble(_heightCm) ?? 170;
  Future<void> setHeightCm(double v) => prefs.setDouble(_heightCm, v);

  double get weightKg => prefs.getDouble(_weightKg) ?? 65;
  Future<void> setWeightKg(double v) => prefs.setDouble(_weightKg, v);

  ActivityLevel get activity =>
      ActivityLevel.values.asNameMap()[prefs.getString(_activity)] ?? ActivityLevel.moderate;
  Future<void> setActivity(ActivityLevel v) => prefs.setString(_activity, v.name);

  int get calorieGoal => prefs.getInt(_calorieGoal) ?? 2000;
  Future<void> setCalorieGoal(int v) => prefs.setInt(_calorieGoal, v);

  int get proteinGoal => prefs.getInt(_proteinGoal) ?? 90;
  Future<void> setProteinGoal(int v) => prefs.setInt(_proteinGoal, v);

  bool get ramadan => prefs.getBool(_ramadan) ?? false;
  Future<void> setRamadan(bool v) => prefs.setBool(_ramadan, v);

  int get retentionDays => prefs.getInt(_retentionDays) ?? 30;
  Future<void> setRetentionDays(int v) => prefs.setInt(_retentionDays, v);

  Future<String?> getApiKey() => secure.read(key: _apiKeyKey);
  Future<void> setApiKey(String v) => secure.write(key: _apiKeyKey, value: v);
  Future<void> clearApiKey() => secure.delete(key: _apiKeyKey);
}

extension _AsNameMap<T extends Enum> on List<T> {
  Map<String, T> asNameMap() => {for (final v in this) v.name: v};
}
