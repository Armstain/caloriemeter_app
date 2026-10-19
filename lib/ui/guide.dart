/// Protein on a budget: live DAM prices ranked by cost per 30g protein.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/lang.dart';
import '../data/app_db.dart';
import '../data/prices.dart';
import '../state/providers.dart';
import 'planner_screen.dart';

class GuideScreen extends ConsumerWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = Lang.of(context);
    final prices = ref.watch(pricesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(lang.t('guide.title'))),
      body: prices.when(
        data: (data) {
          List<ProteinGuideEntry> guide;
          try {
            guide = buildProteinGuide(data);
          } catch (e) {
            return Center(child: Text(e.toString()));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(lang.t('guide.subtitle'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                  '${lang.t('guide.pricesFrom')} ${data.reportDate} (DHAKA)',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.calculate_outlined),
                  label: Text(lang.t('planner.title')),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const PlannerScreen(),
                  )),
                ),
              ),
              const SizedBox(height: 12),
              ...guide.asMap().entries.map((e) => _GuideTile(
                    rank: e.key + 1,
                    entry: e.value,
                    onCorrect: () => _correctPrice(context, ref, e.value.price),
                  )),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
      ),
    );
  }

  Future<void> _correctPrice(
      BuildContext context, WidgetRef ref, PriceItem price) async {
    final lang = Lang.of(context);
    final ctrl = TextEditingController(text: price.mid.round().toString());
    final marketCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(lang.t('guide.correction')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: '${lang.t('guide.paid')} (৳/${price.unit})',
                  border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: marketCtrl,
              decoration: const InputDecoration(
                  labelText: 'Market (optional)',
                  border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(lang.t('common.cancel'))),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(lang.t('guide.saveCorrection'))),
        ],
      ),
    );
    if (ok == true) {
      final v = double.tryParse(ctrl.text);
      if (v != null && v > 0) {
        await AppDb.savePriceCorrection(
            price.id, v, marketCtrl.text.trim().isEmpty ? null : marketCtrl.text.trim());
        ref.invalidate(pricesProvider);
      }
    }
  }
}

class _GuideTile extends StatelessWidget {
  final int rank;
  final ProteinGuideEntry entry;
  final VoidCallback onCorrect;
  const _GuideTile(
      {required this.rank, required this.entry, required this.onCorrect});

  @override
  Widget build(BuildContext context) {
    final lang = Lang.of(context);
    final name =
        lang.locale == 'bn' ? entry.labelBn : entry.labelEn;
    final best = rank == 1;
    return Card(
      color: best ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        leading: CircleAvatar(child: Text(lang.num(rank))),
        title: Text(name,
            style: TextStyle(fontWeight: best ? FontWeight.bold : FontWeight.normal)),
        subtitle: Text(
            '৳${lang.num(entry.price.mid.round())}/${entry.price.unit}${entry.price.corrected ? ' · ✓' : ''}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('৳${lang.num(entry.costPer30g.round())}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(lang.t('guide.per30g'),
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        onLongPress: onCorrect,
      ),
    );
  }
}
