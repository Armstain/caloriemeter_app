/// Settings: language, goals, API key, Ramadan mode, data management.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/lang.dart';
import '../core/nutrition.dart';
import '../data/app_db.dart';
import '../services/settings.dart';
import '../state/providers.dart';
import 'fooddb_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final Future<void> Function(String) onLocaleChanged;
  const SettingsScreen({super.key, required this.onLocaleChanged});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _calCtrl = TextEditingController();
  final _proCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final s = ref.read(settingsProvider);
    if (s == null) return;
    _calCtrl.text = s.calorieGoal.toString();
    _proCtrl.text = s.proteinGoal.toString();
    _keyCtrl.text = (await s.getApiKey()) ?? '';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final lang = Lang.of(context);
    final settings = ref.watch(settingsProvider);
    if (settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: Text(lang.t('settings.title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(lang.t('settings.language')),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'en', label: Text('English')),
              ButtonSegment(value: 'bn', label: Text('বাংলা')),
            ],
            selected: {lang.locale},
            onSelectionChanged: (s) => widget.onLocaleChanged(s.first),
          ),
          const SizedBox(height: 16),
          _section(lang.t('settings.goal')),
          _numberField(lang.t('settings.dailyCalorieGoal'), _calCtrl, (v) {
            final n = int.tryParse(v);
            if (n != null && n > 0) settings.setCalorieGoal(n);
          }),
          const SizedBox(height: 8),
          _numberField(lang.t('settings.dailyProteinGoal'), _proCtrl, (v) {
            final n = int.tryParse(v);
            if (n != null && n > 0) settings.setProteinGoal(n);
          }),
          const SizedBox(height: 8),
          SwitchListTile(
            title: Text(lang.t('settings.ramadan')),
            subtitle: Text(lang.t('settings.ramadanDesc')),
            value: settings.ramadan,
            onChanged: (v) async {
              await settings.setRamadan(v);
              setState(() {});
            },
          ),
          const SizedBox(height: 16),
          _section(lang.t('settings.apiKey')),
          TextField(
            controller: _keyCtrl,
            obscureText: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            onSubmitted: (v) => settings.setApiKey(v.trim()),
          ),
          const SizedBox(height: 16),
          _section(lang.t('fooddb.title')),
          ListTile(
            leading: const Icon(Icons.restaurant_menu_outlined),
            title: Text(lang.t('fooddb.title')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FoodDbScreen())),
          ),
          const SizedBox(height: 16),
          _section(lang.t('settings.deleteAll')),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
            title: Text(lang.t('settings.deleteAll'),
                style: const TextStyle(color: Colors.red)),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text(lang.t('settings.deleteAll')),
                  content: Text(lang.t('settings.confirmDeleteAll')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: Text(lang.t('common.cancel'))),
                    TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: Text(lang.t('common.delete'))),
                  ],
                ),
              );
              if (ok == true) {
                await AppDb.deleteAll();
                await settings.clearApiKey();
                if (context.mounted) {
                  ref.invalidate(todayEntriesProvider);
                  ref.invalidate(todayTotalsProvider);
                  ref.invalidate(waterProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(lang.t('common.ok'))));
                }
              }
            },
          ),
          const SizedBox(height: 24),
          Center(
            child: Text('${lang.t('settings.version')} 0.1.0',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      );

  Widget _numberField(
      String label, TextEditingController ctrl, ValueChanged<String> onSubmit) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      onSubmitted: onSubmit,
    );
  }
}
