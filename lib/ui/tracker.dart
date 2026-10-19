/// Diary tab: browse any day's entries + water.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/lang.dart';
import '../data/app_db.dart';
import '../data/models.dart';
import '../state/providers.dart';

class TrackerScreen extends ConsumerStatefulWidget {
  const TrackerScreen({super.key});

  @override
  ConsumerState<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends ConsumerState<TrackerScreen> {
  late String _date;

  @override
  void initState() {
    super.initState();
    _date = AppDb.todayKey();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Lang.of(context);
    final isToday = _date == AppDb.todayKey();
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.t('home.diary')),
        actions: [
          if (isToday)
            IconButton(
              icon: const Icon(Icons.repeat),
              tooltip: lang.t('repeat.yesterday'),
              onPressed: _repeatYesterday,
            ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.parse(_date),
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _date = AppDb.todayKey(picked));
            },
          ),
        ],
      ),
      body: FutureBuilder<List<FoodEntry>>(
        future: AppDb.entriesForDay(_date),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snap.data!;
          final kcal = entries.fold(0.0, (s, e) => s + e.totalCalories);
          final protein = entries.fold(0.0, (s, e) => s + e.totalMacros.protein);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat(lang.t('common.kcal'), lang.num(kcal.round())),
                      _stat(lang.t('common.protein'), '${lang.num(protein.round())}g'),
                      _stat(lang.t('diary.entries'), lang.num(entries.length)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text(lang.t('home.noEntries'))),
                ),
              ...entries.map((e) => _DiaryTile(
                    entry: e,
                    onChanged: () => setState(() {}),
                  )),
            ],
          );
        },
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
        children: [
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      );

  Future<void> _repeatYesterday() async {
    final lang = Lang.of(context);
    final yKey =
        AppDb.todayKey(DateTime.now().subtract(const Duration(days: 1)));
    final entries = await AppDb.entriesForDay(yKey);
    if (!mounted) return;
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.t('repeat.nothingToCopy'))),
      );
      return;
    }
    final now = DateTime.now();
    var i = 0;
    for (final e in entries) {
      await AppDb.saveEntry(FoodEntry(
        id: 'e${now.millisecondsSinceEpoch}_${i++}',
        timestamp: now,
        date: _date,
        mealType: e.mealType,
        foods: e.foods,
        totalCalories: e.totalCalories,
        totalMacros: e.totalMacros,
      ));
    }
    if (!mounted) return;
    setState(() {});
    ref.invalidate(todayEntriesProvider);
    ref.invalidate(todayTotalsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${lang.t('repeat.copied')} (${entries.length})')),
    );
  }
}

class _DiaryTile extends ConsumerWidget {
  final FoodEntry entry;
  final VoidCallback onChanged;
  const _DiaryTile({required this.entry, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = Lang.of(context);
    return Card(
      child: ListTile(
        leading: entry.imagePath != null && File(entry.imagePath!).existsSync()
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(entry.imagePath!),
                    width: 56, height: 56, fit: BoxFit.cover),
              )
            : const Icon(Icons.restaurant_outlined, size: 40),
        title: Text(entry.foods.map((f) => f.name).join(', '),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
            '${lang.num(entry.totalCalories.round())} ${lang.t('common.kcal')} · ${lang.num(entry.totalMacros.protein.round())}g ${lang.t('common.protein')}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            await AppDb.deleteEntry(entry.id);
            onChanged();
            ref.invalidate(todayEntriesProvider);
            ref.invalidate(todayTotalsProvider);
          },
        ),
      ),
    );
  }
}
