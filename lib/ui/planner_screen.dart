/// Budget meal planner screen: "৳150/day, 120g protein" -> shopping list.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/lang.dart';
import '../data/app_db.dart';
import '../data/models.dart';
import '../data/planner.dart';
import '../state/providers.dart';

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  final _budgetCtrl = TextEditingController(text: '150');
  final _proteinCtrl = TextEditingController();
  MealPlan? _plan;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    final goal = ref.read(settingsProvider)?.proteinGoal ?? 120;
    _proteinCtrl.text = goal.toString();
  }

  Future<void> _run() async {
    final budget = double.tryParse(_budgetCtrl.text) ?? 0;
    final target = double.tryParse(_proteinCtrl.text) ?? 0;
    if (budget <= 0 || target <= 0) return;
    setState(() => _working = true);
    try {
      final prices = await ref.read(pricesProvider.future);
      final plan = planDay(budgetTk: budget, proteinTargetG: target, prices: prices);
      if (mounted) setState(() => _plan = plan);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _logItem(PlanItem item) async {
    final lang = Lang.of(context);
    final now = DateTime.now();
    final entry = FoodEntry(
      id: 'e${now.millisecondsSinceEpoch}',
      timestamp: now,
      date: AppDb.todayKey(now),
      mealType: 'lunch',
      foods: [
        AnalyzedFood(
          name: '${item.candidate.labelEn} (${item.steps}x ${item.candidate.stepDescEn})',
          calories: item.kcal,
          quantity: '${item.steps} x ${item.candidate.stepDescEn}',
          confidence: 1.0,
          macros: Macros(protein: item.proteinG),
          category: 'protein',
        ),
      ],
      totalCalories: item.kcal,
      totalMacros: Macros(protein: item.proteinG),
    );
    await AppDb.saveEntry(entry);
    ref.invalidate(todayEntriesProvider);
    ref.invalidate(todayTotalsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.t('planner.logged'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Lang.of(context);
    final plan = _plan;
    return Scaffold(
      appBar: AppBar(title: Text(lang.t('planner.title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(lang.t('planner.subtitle')),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _budgetCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: lang.t('planner.budget'),
                    prefixText: '৳ ',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _proteinCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: lang.t('planner.proteinTarget'),
                    suffixText: 'g',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _working ? null : _run,
              child: _working
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(lang.t('planner.plan')),
            ),
          ),
          if (plan != null) ...[
            const SizedBox(height: 16),
            _SummaryCard(plan: plan),
            const SizedBox(height: 8),
            if (plan.items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text(lang.t('planner.budgetTooLow'))),
              ),
            ...plan.items.map((i) => _PlanTile(item: i, onLog: () => _logItem(i))),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final MealPlan plan;
  const _SummaryCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final lang = Lang.of(context);
    final proteinProgress = plan.proteinTarget > 0
        ? (plan.totalProtein / plan.proteinTarget).clamp(0.0, 1.0)
        : 0.0;
    return Card(
      color: plan.hitTarget
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(lang.t('planner.totalProtein'),
                    style: Theme.of(context).textTheme.titleSmall),
                Text(
                    '${lang.num(plan.totalProtein.round())}g / ${lang.num(plan.proteinTarget.round())}g',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: proteinProgress, minHeight: 8),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(lang.t('planner.totalCost')),
                Text('৳${lang.num(plan.totalCost.round())} / ৳${lang.num(plan.budget.round())}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${lang.num(plan.totalKcal.round())} ${lang.t('common.kcal')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (plan.trimmed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(lang.t('planner.trimmed'),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  final PlanItem item;
  final VoidCallback onLog;
  const _PlanTile({required this.item, required this.onLog});

  @override
  Widget build(BuildContext context) {
    final lang = Lang.of(context);
    final c = item.candidate;
    final name = lang.locale == 'bn' ? c.labelBn : c.labelEn;
    final step = lang.locale == 'bn' ? c.stepDescBn : c.stepDescEn;
    return Card(
      child: ListTile(
        title: Text('$name — ${item.steps} × $step'),
        subtitle: Text(
            '${lang.num(item.proteinG.round())}g ${lang.t('common.protein')} · ${lang.num(item.kcal.round())} ${lang.t('common.kcal')}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('৳${lang.num(item.costTk.round())}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: lang.t('planner.log'),
              onPressed: onLog,
            ),
          ],
        ),
      ),
    );
  }
}
