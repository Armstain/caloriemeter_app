/// Analysis flow: runs Gemini on the photo, lets the user review/edit,
// then saves. Corrections are stored as training data for future models.
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../core/lang.dart';
import '../data/app_db.dart';
import '../data/models.dart';
import '../services/gemini.dart';
import '../state/providers.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  final File imageFile;
  final String apiKey;
  const AnalysisScreen({super.key, required this.imageFile, required this.apiKey});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  List<AnalyzedFood>? _foods;
  String? _error;
  bool _saving = false;
  String _mealType = 'lunch';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final bytes = await widget.imageFile.readAsBytes();
      final foods = await GeminiClient(widget.apiKey).analyzeFood(base64Encode(bytes));
      if (mounted) setState(() => _foods = foods);
    } on GeminiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  double get _totalKcal =>
      (_foods ?? []).fold(0.0, (s, f) => s + f.calories);
  Macros get _totalMacros =>
      (_foods ?? []).fold(const Macros(), (s, f) => s + f.macros);

  Future<void> _save() async {
    if (_foods == null || _saving) return;
    setState(() => _saving = true);
    try {
      // Persist the photo next to the DB so history shows thumbnails.
      final dir = await getApplicationDocumentsDirectory();
      final dest = File(
          '${dir.path}/meal_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await widget.imageFile.copy(dest.path);

      final now = DateTime.now();
      final entry = FoodEntry(
        id: 'e${now.millisecondsSinceEpoch}',
        timestamp: now,
        date: AppDb.todayKey(now),
        mealType: _mealType,
        foods: _foods!,
        totalCalories: _totalKcal,
        totalMacros: _totalMacros,
        imagePath: dest.path,
      );
      await AppDb.saveEntry(entry);
      ref.invalidate(todayEntriesProvider);
      ref.invalidate(todayTotalsProvider);
      if (mounted) {
        ref.read(tabProvider.notifier).state = 0;
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Lang.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(lang.t('results.title'))),
      body: _error != null
          ? _ErrorView(message: _error!, onRetry: () {
              setState(() {
                _error = null;
                _foods = null;
              });
              _run();
            })
          : _foods == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(widget.imageFile,
                            height: 200, fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(lang.t('results.analyzing')),
                    ],
                  ),
                )
              : _ResultsView(
                  foods: _foods!,
                  imageFile: widget.imageFile,
                  mealType: _mealType,
                  onMealType: (m) => setState(() => _mealType = m),
                  onFoodsChanged: (f) => setState(() => _foods = f),
                  onSave: _save,
                  saving: _saving,
                  onDiscard: () => Navigator.of(context).pop(),
                ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final lang = Lang.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: Text(lang.t('common.retry'))),
          ],
        ),
      ),
    );
  }
}

class _ResultsView extends StatelessWidget {
  final List<AnalyzedFood> foods;
  final File imageFile;
  final String mealType;
  final ValueChanged<String> onMealType;
  final ValueChanged<List<AnalyzedFood>> onFoodsChanged;
  final VoidCallback onSave;
  final VoidCallback onDiscard;
  final bool saving;

  const _ResultsView({
    required this.foods,
    required this.imageFile,
    required this.mealType,
    required this.onMealType,
    required this.onFoodsChanged,
    required this.onSave,
    required this.onDiscard,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    final lang = Lang.of(context);
    final kcal = foods.fold(0.0, (s, f) => s + f.calories);
    final macros = foods.fold(const Macros(), (s, f) => s + f.macros);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(imageFile, height: 180, width: double.infinity, fit: BoxFit.cover),
              ),
              const SizedBox(height: 12),
              Text('${lang.t('results.mealType')}:',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              _MealTypeChips(current: mealType, onChanged: onMealType),
              const SizedBox(height: 12),
              ...foods.asMap().entries.map((e) => _FoodCard(
                    food: e.value,
                    index: e.key,
                    onChanged: (updated) {
                      final next = [...foods];
                      next[e.key] = updated;
                      onFoodsChanged(next);
                    },
                    onRemove: () {
                      final next = [...foods]..removeAt(e.key);
                      onFoodsChanged(next);
                    },
                  )),
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _total(lang.t('common.kcal'), lang.num(kcal.round())),
                      _total(lang.t('common.protein'),
                          '${lang.num(macros.protein.round())}g'),
                      _total(lang.t('common.carbs'),
                          '${lang.num(macros.carbs.round())}g'),
                      _total(lang.t('common.fat'),
                          '${lang.num(macros.fat.round())}g'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: saving ? null : onDiscard,
                  child: Text(lang.t('results.discard')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: saving || foods.isEmpty ? null : onSave,
                  child: saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(lang.t('results.save')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _total(String label, String value) => Column(
        children: [
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );
}

class _MealTypeChips extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _MealTypeChips({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final lang = Lang.of(context);
    // Ramadan toggle swaps snack out for sehri/iftar; keep all visible is fine.
    const types = ['breakfast', 'lunch', 'dinner', 'snack', 'sehri', 'iftar'];
    const keys = {
      'breakfast': 'results.breakfast',
      'lunch': 'results.lunch',
      'dinner': 'results.dinner',
      'snack': 'results.snack',
      'sehri': 'results.sehri',
      'iftar': 'results.iftar',
    };
    return Wrap(
      spacing: 8,
      children: types
          .map((t) => ChoiceChip(
                label: Text(lang.t(keys[t]!)),
                selected: current == t,
                onSelected: (_) => onChanged(t),
              ))
          .toList(),
    );
  }
}

class _FoodCard extends StatelessWidget {
  final AnalyzedFood food;
  final int index;
  final ValueChanged<AnalyzedFood> onChanged;
  final VoidCallback onRemove;
  const _FoodCard(
      {required this.food,
      required this.index,
      required this.onChanged,
      required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final lang = Lang.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(food.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Text(
                    '${lang.num((food.confidence * 100).round())}% ${lang.t('results.confidence')}',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.grey)),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onRemove,
                ),
              ],
            ),
            if (food.quantity.isNotEmpty)
              Text(food.quantity,
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _NumField(
                    key: ValueKey('kcal$index'),
                    label: lang.t('common.kcal'),
                    value: food.calories,
                    onChanged: (v) => onChanged(_copy(food, calories: v)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _NumField(
                    key: ValueKey('pro$index'),
                    label: '${lang.t('common.protein')} (g)',
                    value: food.macros.protein,
                    onChanged: (v) => onChanged(_copy(food,
                        macros: Macros(
                            protein: v,
                            carbs: food.macros.carbs,
                            fat: food.macros.fat,
                            fiber: food.macros.fiber))),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  AnalyzedFood _copy(AnalyzedFood f, {double? calories, Macros? macros}) =>
      AnalyzedFood(
        name: f.name,
        calories: calories ?? f.calories,
        quantity: f.quantity,
        confidence: f.confidence,
        ingredients: f.ingredients,
        cookingMethod: f.cookingMethod,
        macros: macros ?? f.macros,
        category: f.category,
        healthScore: f.healthScore,
      );

/// Number field that keeps its controller (and cursor) across rebuilds.
class _NumField extends StatefulWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  const _NumField(
      {super.key, required this.label, required this.value, required this.onChanged});

  @override
  State<_NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<_NumField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value.round().toString());
  }

  @override
  void didUpdateWidget(_NumField old) {
    super.didUpdateWidget(old);
    // If the value changed externally (not from typing), reflect it.
    final parsed = double.tryParse(_ctrl.text);
    if (parsed == null || (parsed - widget.value).abs() > 0.51) {
      _ctrl.text = widget.value.round().toString();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
          labelText: widget.label, border: const OutlineInputBorder(), isDense: true),
      onChanged: (s) {
        final v = double.tryParse(s);
        if (v != null) widget.onChanged(v);
      },
    );
  }
}
