/// Local notification reminders: meal logging nudges + water.
/// Android-focused; uses inexact alarms (no exact-alarm permission needed).
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'settings.dart';

class Reminders {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone));
    } catch (_) {
      // Fall back to UTC-based tz.local; times may drift on exotic zones.
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    await _plugin.initialize(
        const InitializationSettings(android: android, iOS: darwin, macOS: darwin));
    _ready = true;
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// (Re)schedules everything from current settings. Call on app start and
  /// whenever reminder settings change.
  static Future<void> reschedule({
    required bool mealReminders,
    required List<String> mealTimes, // ["08:00", "13:00", "20:00"]
    required List<String> mealTitles,
    required List<String> mealBodies,
    required bool waterReminder,
    required String waterTitle,
    required String waterBody,
  }) async {
    if (!_ready) return;
    await _plugin.cancelAll();
    var id = 0;
    if (mealReminders) {
      for (var i = 0; i < mealTimes.length && i < mealTitles.length; i++) {
        await _daily(id++, mealTimes[i], mealTitles[i],
            i < mealBodies.length ? mealBodies[i] : '');
      }
    }
    if (waterReminder) {
      for (final t in const ['10:00', '15:00', '19:00']) {
        await _daily(id++, t, waterTitle, waterBody);
      }
    }
  }

  /// Reschedule from persisted settings + loaded strings. Safe to call often.
  static Future<void> rescheduleFrom(
      Settings settings, Map<String, dynamic> strings) {
    String t(String path) {
      dynamic node = strings;
      for (final part in path.split('.')) {
        if (node is Map<String, dynamic> && node.containsKey(part)) {
          node = node[part];
        } else {
          return path;
        }
      }
      return node is String ? node : path;
    }

    final body = t('reminders.logBody');
    return reschedule(
      mealReminders: settings.mealReminders,
      mealTimes: [
        settings.breakfastTime,
        settings.lunchTime,
        settings.dinnerTime
      ],
      mealTitles: [
        t('reminders.logBreakfast'),
        t('reminders.logLunch'),
        t('reminders.logDinner'),
      ],
      mealBodies: [body, body, body],
      waterReminder: settings.waterReminder,
      waterTitle: t('reminders.drinkWater'),
      waterBody: t('reminders.drinkWaterBody'),
    );
  }

  static Future<void> _daily(
      int id, String hhmm, String title, String body) async {
    final parts = hhmm.split(':');
    if (parts.length != 2) return;
    final h = int.tryParse(parts[0]), m = int.tryParse(parts[1]);
    if (h == null || m == null) return;
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
    if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          'Reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
