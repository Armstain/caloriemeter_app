import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'core/lang.dart';
import 'services/settings.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  const secure = FlutterSecureStorage();
  final settings = Settings(prefs, secure);
  final strings = await loadStrings(settings.locale);
  runApp(ProviderScope(
      child: CaloriemeterApp(settings: settings, strings: strings)));
}
