/// Plate calculator: what plates to load per side for a target bar weight.
library;

import 'package:flutter/material.dart';
import '../core/lang.dart';

const _barKg = 20.0;
const _plates = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25];

List<double> platesFor(double targetKg) {
  var perSide = (targetKg - _barKg) / 2;
  if (perSide <= 0) return [];
  final out = <double>[];
  for (final p in _plates) {
    while (perSide >= p - 1e-9) {
      out.add(p);
      perSide -= p;
    }
  }
  return out;
}

Future<void> showPlateCalculator(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _PlateSheet(),
  );
}

class _PlateSheet extends StatefulWidget {
  const _PlateSheet();
  @override
  State<_PlateSheet> createState() => _PlateSheetState();
}

class _PlateSheetState extends State<_PlateSheet> {
  final _ctrl = TextEditingController(text: '60');

  @override
  Widget build(BuildContext context) {
    final lang = Lang.of(context);
    final target = double.tryParse(_ctrl.text) ?? 0;
    final plates = platesFor(target);
    final loaded = _barKg + plates.fold(0.0, (s, p) => s + p) * 2;
    return Padding(
      padding: EdgeInsets.only(
          left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lang.t('workout.plateCalc'),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: lang.t('workout.targetWeight'),
              suffixText: 'kg',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          if (target <= _barKg)
            Text(lang.t('workout.justTheBar'))
          else ...[
            Text(lang.t('workout.perSide'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in plates)
                  Chip(
                    label: Text('${p.toStringAsFixed(p < 10 ? 1 : 0)} kg'),
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${lang.t('workout.loaded')}: ${loaded.toStringAsFixed(1)} kg',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ],
      ),
    );
  }
}
