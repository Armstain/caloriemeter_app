/// Budget meal planner: hit a protein target within a taka budget.
/// Greedy optimizer over live DAM prices + curated protein values.
/// Pure logic — no widgets, no I/O.
library;

import 'prices.dart';

/// One purchasable protein source.
class PlanCandidate {
  final String priceId;
  final String labelEn;
  final String labelBn;
  final double proteinPerStep; // grams of protein per purchase step
  final double kcalPerStep;
  final double stepFraction; // fraction of the price unit (kg/piece)
  final String stepDescEn; // "1 egg", "100g"
  final String stepDescBn;
  final int maxSteps; // realistic daily cap

  const PlanCandidate({
    required this.priceId,
    required this.labelEn,
    required this.labelBn,
    required this.proteinPerStep,
    required this.kcalPerStep,
    required this.stepFraction,
    required this.stepDescEn,
    required this.stepDescBn,
    required this.maxSteps,
  });
}

const _candidates = <PlanCandidate>[
  PlanCandidate(
      priceId: 'egg_farm',
      labelEn: 'Farm egg',
      labelBn: 'ফার্মের ডিম',
      proteinPerStep: 6.5,
      kcalPerStep: 70,
      stepFraction: 1,
      stepDescEn: '1 egg',
      stepDescBn: '১টি ডিম',
      maxSteps: 6),
  PlanCandidate(
      priceId: 'chicken_broiler',
      labelEn: 'Broiler chicken',
      labelBn: 'ব্রয়লার মুরগি',
      proteinPerStep: 20,
      kcalPerStep: 130,
      stepFraction: 0.1,
      stepDescEn: '100g',
      stepDescBn: '১০০গ্রাম',
      maxSteps: 3),
  PlanCandidate(
      priceId: 'fish_tilapia',
      labelEn: 'Tilapia',
      labelBn: 'তেলাপিয়া',
      proteinPerStep: 20,
      kcalPerStep: 110,
      stepFraction: 0.1,
      stepDescEn: '100g',
      stepDescBn: '১০০গ্রাম',
      maxSteps: 3),
  PlanCandidate(
      priceId: 'fish_rui',
      labelEn: 'Rui fish',
      labelBn: 'রুই মাছ',
      proteinPerStep: 18,
      kcalPerStep: 105,
      stepFraction: 0.1,
      stepDescEn: '100g',
      stepDescBn: '১০০গ্রাম',
      maxSteps: 3),
  PlanCandidate(
      priceId: 'fish_katla',
      labelEn: 'Katla fish',
      labelBn: 'কাতলা মাছ',
      proteinPerStep: 18,
      kcalPerStep: 105,
      stepFraction: 0.1,
      stepDescEn: '100g',
      stepDescBn: '১০০গ্রাম',
      maxSteps: 3),
  PlanCandidate(
      priceId: 'fish_pangas',
      labelEn: 'Pangas fish',
      labelBn: 'পাঙ্গাস মাছ',
      proteinPerStep: 16,
      kcalPerStep: 120,
      stepFraction: 0.1,
      stepDescEn: '100g',
      stepDescBn: '১০০গ্রাম',
      maxSteps: 3),
  PlanCandidate(
      priceId: 'soya',
      labelEn: 'Soya chunks',
      labelBn: 'সয়া চাংক',
      proteinPerStep: 15.6,
      kcalPerStep: 100,
      stepFraction: 0.03,
      stepDescEn: '30g dry',
      stepDescBn: '৩০গ্রাম',
      maxSteps: 2),
  PlanCandidate(
      priceId: 'lentil_coarse',
      labelEn: 'Musur dal',
      labelBn: 'মসুর ডাল',
      proteinPerStep: 12,
      kcalPerStep: 160,
      stepFraction: 0.05,
      stepDescEn: '50g dry',
      stepDescBn: '৫০গ্রাম',
      maxSteps: 2),
  PlanCandidate(
      priceId: 'chickpea',
      labelEn: 'Chickpea',
      labelBn: 'ছোলা',
      proteinPerStep: 9.5,
      kcalPerStep: 180,
      stepFraction: 0.05,
      stepDescEn: '50g dry',
      stepDescBn: '৫০গ্রাম',
      maxSteps: 2),
  PlanCandidate(
      priceId: 'peanut',
      labelEn: 'Peanuts',
      labelBn: 'চিনাবাদাম',
      proteinPerStep: 7.8,
      kcalPerStep: 170,
      stepFraction: 0.03,
      stepDescEn: '30g',
      stepDescBn: '৩০গ্রাম',
      maxSteps: 2),
  PlanCandidate(
      priceId: 'whey',
      labelEn: 'Whey protein',
      labelBn: 'হোয়ে প্রোটিন',
      proteinPerStep: 24,
      kcalPerStep: 120,
      stepFraction: 0.03,
      stepDescEn: '1 scoop',
      stepDescBn: '১ স্কুপ',
      maxSteps: 2),
];

class PlanItem {
  final PlanCandidate candidate;
  final int steps;
  final double costTk;
  const PlanItem({required this.candidate, required this.steps, required this.costTk});

  double get proteinG => candidate.proteinPerStep * steps;
  double get kcal => candidate.kcalPerStep * steps;
}

class MealPlan {
  final List<PlanItem> items;
  final double totalProtein;
  final double totalKcal;
  final double totalCost;
  final double proteinTarget;
  final double budget;
  final bool trimmed; // true when the plan was cut to fit the budget

  const MealPlan({
    required this.items,
    required this.totalProtein,
    required this.totalKcal,
    required this.totalCost,
    required this.proteinTarget,
    required this.budget,
    required this.trimmed,
  });

  bool get hitTarget => totalProtein >= proteinTarget;
  bool get withinBudget => totalCost <= budget;
}

/// Curated defaults for protein sources DAM doesn't track.
const _curatedMid = <String, double>{
  'soya': 220, // per kg
  'peanut': 180, // per kg
  'whey': 9500, // per kg
};

double _midFor(String priceId, PriceData prices) {
  final p = prices.retail[priceId];
  if (p != null && p.mid > 0) return p.mid;
  return _curatedMid[priceId] ?? 0;
}

/// Greedy: cheapest protein-per-taka first, up to each food's cap, until the
/// target is hit. Then trims the most expensive steps until it fits the budget.
MealPlan planDay({
  required double budgetTk,
  required double proteinTargetG,
  required PriceData prices,
}) {
  final priced = <({PlanCandidate c, double costPerStep})>[];
  for (final c in _candidates) {
    final mid = _midFor(c.priceId, prices);
    if (mid <= 0) continue;
    priced.add((c: c, costPerStep: mid * c.stepFraction));
  }
  // Most protein per taka first.
  priced.sort((a, b) =>
      (b.c.proteinPerStep / b.costPerStep).compareTo(a.c.proteinPerStep / a.costPerStep));

  final counts = <PlanCandidate, int>{};
  double protein = 0;
  for (final pc in priced) {
    if (protein >= proteinTargetG) break;
    var steps = 0;
    while (steps < pc.c.maxSteps && protein < proteinTargetG) {
      steps++;
      protein += pc.c.proteinPerStep;
    }
    if (steps > 0) counts[pc.c] = steps;
  }

  double costOf(Map<PlanCandidate, int> m) {
    double total = 0;
    for (final e in m.entries) {
      total += _midFor(e.key.priceId, prices) * e.key.stepFraction * e.value;
    }
    return total;
  }

  // Trim most-expensive steps first until within budget.
  bool trimmed = false;
  var cost = costOf(counts);
  while (cost > budgetTk && counts.isNotEmpty) {
    PlanCandidate? worst;
    double worstPerStep = -1;
    for (final e in counts.entries) {
      final perStep = _midFor(e.key.priceId, prices) * e.key.stepFraction;
      if (perStep > worstPerStep) {
        worstPerStep = perStep;
        worst = e.key;
      }
    }
    if (worst == null) break;
    final n = counts[worst]! - 1;
    if (n <= 0) {
      counts.remove(worst);
    } else {
      counts[worst] = n;
    }
    protein -= worst.proteinPerStep;
    trimmed = true;
    cost = costOf(counts);
  }

  final items = counts.entries
      .map((e) => PlanItem(
            candidate: e.key,
            steps: e.value,
            costTk: _midFor(e.key.priceId, prices) * e.key.stepFraction * e.value,
          ))
      .toList();
  double proteinPerTaka(PlanItem i) {
    final perStep = _midFor(i.candidate.priceId, prices) * i.candidate.stepFraction;
    return perStep <= 0 ? 0 : i.candidate.proteinPerStep / perStep;
  }

  // Cheapest protein-per-taka first for display.
  items.sort((a, b) => proteinPerTaka(b).compareTo(proteinPerTaka(a)));

  return MealPlan(
    items: items,
    totalProtein: protein,
    totalKcal: items.fold(0.0, (s, i) => s + i.kcal),
    totalCost: cost,
    proteinTarget: proteinTargetG,
    budget: budgetTk,
    trimmed: trimmed,
  );
}
