/// Food database browser: bilingual search, portion picker, save as entry.
/// Corrections to kcal/protein are stored as AI training data.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/lang.dart';
import '../data/app_db.dart';
import '../data/food_db.dart';
import '../data/models.dart';
import '../state/providers.dart';

class FoodDbScreen extends ConsumerStatefulWidget {
  final DbFood? preselect;
  const FoodDbScreen({super.key, this.preselect});

  @override
  ConsumerState<FoodDbScreen> createState() => _FoodDbScreenState();
}

class _FoodDbScreenState extends ConsumerState<FoodDbScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    if (widget.preselect != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openAdd(widget.preselect!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Lang.of(context);
    final dbAsync = ref.watch(foodDbProvider);
    return Scaffold(
      appBar: AppBar(title: Text(lang.t('fooddb.title'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: lang.t('fooddb.search'),
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(lang.t('fooddb.estimatesNote'),
                style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: dbAsync.when(
              data: (db) {
                final results = db.search(_query);
                return ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (c, i) => _FoodTile(
                      food: results[i], onTap: () => _openAdd(results[i])),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAdd(DbFood food) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddSheet(food: food),
    );
    if (added == true && mounted) {
      ref.invalidate(todayEntriesProvider);
      ref.invalidate(todayTotalsProvider);
      Navigator.of(context).pop();
    }
  }
}

class _FoodTile extends StatelessWidget {
  final DbFood food;
  final VoidCallback onTap;
  const _FoodTile({required this.food, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final lang = Lang.of(context);
    final name = lang.locale == 'bn' && food.nameBn.isNotEmpty ? food.nameBn : food.nameEn;
    final sub = lang.locale == 'bn' && food.nameBn.isNotEmpty ? food.nameEn : food.nameBn;
    return ListTile(
      title: Text(name),
      subtitle: sub.isNotEmpty ? Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
      trailing: Text('${lang.num(food.kcal100.round())} ${lang.t('common.kcal')}/100g',
          style: const TextStyle(color: Colors.grey)),
      onTap: onTap,
    );
  }
}

class _AddSheet extends ConsumerStatefulWidget {
  final DbFood food;
  const _AddSheet({required this.food});

  @override
  ConsumerState<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends ConsumerState<_AddSheet> {
  late PortionUnit _portion;
  double _count = 1;
  String _mealType = 'lunch';

  @override
  void initState() {
    super.initState();
    _portion = widget.food.portions.isNotEmpty
        ? widget.food.portions.first
        : const PortionUnit(unit: 'plate', grams: 250);
  }

  @override
  Widget build(BuildContext context) {
    final lang = Lang.of(context);
    final f = widget.food;
    final grams = _portion.grams * _count;
    final kcal = f.kcal100 * grams / 100;
    final protein = f.protein100 * grams / 100;
    final name = lang.locale == 'bn' && f.nameBn.isNotEmpty ? f.nameBn : f.nameEn;

    return Padding(
      padding: EdgeInsets.only(
          left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(lang.t('fooddb.portions'), style: Theme.of(context).textTheme.titleSmall),
          Wrap(
            spacing: 8,
            children: f.portions.map((p) {
              final label = lang.locale == 'bn'
                  ? (p.labelBn ?? p.unit)
                  : (p.labelEn ?? p.unit);
              return ChoiceChip(
                label: Text('$label (${lang.num(p.grams.round())}g)'),
                selected: _portion == p,
                onSelected: (_) => setState(() => _portion = p),
              );
            }).toList(),
          ),
          Row(
            children: [
              Text('${lang.t('fooddb.portions')}: '),
              IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () => setState(() => _count = (_count - 0.5).clamp(0.5, 10))),
              Text(lang.num(_count), style: const TextStyle(fontSize: 18)),
              IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => setState(() => _count = (_count + 0.5).clamp(0.5, 10))),
              const Spacer(),
              Text(
                  '${lang.num(kcal.round())} ${lang.t('common.kcal')} · ${lang.num(protein.round())}g ${lang.t('common.protein')}'),
            ],
          ),
          const SizedBox(height: 12),
          Text(lang.t('results.mealType'), style: Theme.of(context).textTheme.titleSmall),
          Wrap(
            spacing: 8,
            children: ['breakfast', 'lunch', 'dinner', 'snack']
                .map((t) => ChoiceChip(
                      label: Text(lang.t('results.$t')),
                      selected: _mealType == t,
                      onSelected: (_) => setState(() => _mealType = t),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _save(context),
            child: Text(lang.t('results.save')),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final f = widget.food;
    final grams = _portion.grams * _count;
    final now = DateTime.now();
    final entry = FoodEntry(
      id: 'e${now.millisecondsSinceEpoch}',
      timestamp: now,
      date: AppDb.todayKey(now),
      mealType: _mealType,
      foods: [
        AnalyzedFood(
          name: f.nameEn,
          calories: f.kcal100 * grams / 100,
          quantity:
              '$_count x ${_portion.unit} (${grams.round()}g)',
          confidence: 1.0,
          macros: Macros(
            protein: f.protein100 * grams / 100,
            carbs: f.carbs100 * grams / 100,
            fat: f.fat100 * grams / 100,
            fiber: f.fiber100 * grams / 100,
          ),
          category: f.category,
        ),
      ],
      totalCalories: f.kcal100 * grams / 100,
      totalMacros: Macros(
        protein: f.protein100 * grams / 100,
        carbs: f.carbs100 * grams / 100,
        fat: f.fat100 * grams / 100,
        fiber: f.fiber100 * grams / 100,
      ),
    );
    await AppDb.saveEntry(entry);
    if (context.mounted) Navigator.of(context).pop(true);
  }
}
