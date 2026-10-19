/// Root widget: locale, theme, onboarding gate, bottom navigation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/lang.dart';
import '../services/settings.dart';
import '../state/providers.dart';
import 'onboarding.dart';
import 'capture.dart';
import 'tracker.dart';
import 'history.dart';
import 'guide.dart';
import 'settings.dart';
import 'workout_screen.dart';

class CaloriemeterApp extends ConsumerStatefulWidget {
  final Settings settings;
  final Map<String, dynamic> strings;
  const CaloriemeterApp({super.key, required this.settings, required this.strings});

  @override
  ConsumerState<CaloriemeterApp> createState() => _CaloriemeterAppState();
}

class _CaloriemeterAppState extends ConsumerState<CaloriemeterApp> {
  late String _locale;
  late Map<String, dynamic> _strings;

  @override
  void initState() {
    super.initState();
    _locale = widget.settings.locale;
    _strings = widget.strings;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(settingsProvider.notifier).state = widget.settings;
      ref.read(localeProvider.notifier).state = _locale;
    });
  }

  Future<void> _setLocale(String locale) async {
    final strings = await loadStrings(locale);
    await widget.settings.setLocale(locale);
    setState(() {
      _locale = locale;
      _strings = strings;
    });
    ref.read(localeProvider.notifier).state = locale;
  }

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF2E7D32),
    );
    return Lang(
      locale: _locale,
      strings: _strings,
      child: Builder(
        builder: (context) => MaterialApp(
          title: Lang.of(context).t('appName'),
          debugShowCheckedModeBanner: false,
          theme: base.copyWith(
            textTheme: GoogleFonts.notoSansBengaliTextTheme(base.textTheme),
          ),
          home: widget.settings.onboarded
              ? MainShell(onLocaleChanged: _setLocale)
              : OnboardingFlow(
                  settings: widget.settings,
                  onDone: () async {
                    await widget.settings.setOnboarded(true);
                    setState(() {});
                  },
                  onLocaleChanged: _setLocale,
                ),
        ),
      ),
    );
  }
}

class MainShell extends ConsumerWidget {
  final Future<void> Function(String) onLocaleChanged;
  const MainShell({super.key, required this.onLocaleChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(tabProvider);
    final lang = Lang.of(context);
    final screens = [
      const CaptureScreen(),
      const WorkoutScreen(),
      const TrackerScreen(),
      const HistoryScreen(),
      const GuideScreen(),
      SettingsScreen(onLocaleChanged: onLocaleChanged),
    ];
    return Scaffold(
      body: IndexedStack(index: tab, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => ref.read(tabProvider.notifier).state = i,
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.camera_alt_outlined),
              selectedIcon: const Icon(Icons.camera_alt),
              label: lang.t('home.capture')),
          NavigationDestination(
              icon: const Icon(Icons.fitness_center_outlined),
              selectedIcon: const Icon(Icons.fitness_center),
              label: lang.t('workout.title')),
          NavigationDestination(
              icon: const Icon(Icons.book_outlined),
              selectedIcon: const Icon(Icons.book),
              label: lang.t('home.diary')),
          NavigationDestination(
              icon: const Icon(Icons.history_outlined),
              selectedIcon: const Icon(Icons.history),
              label: lang.t('history.title')),
          NavigationDestination(
              icon: const Icon(Icons.savings_outlined),
              selectedIcon: const Icon(Icons.savings),
              label: lang.t('guide.title')),
          NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: lang.t('home.settings')),
        ],
      ),
    );
  }
}
