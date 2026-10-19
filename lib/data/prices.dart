/// Live price feed: fetches data/prices.json published by the DAM scraper
/// Action, falls back to the bundled copy, applies on-device user corrections.
library;

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import 'app_db.dart';

class PriceItem {
  final String id;
  final String nameBn;
  final String unit; // kg | litre | piece | 4pcs
  final double min;
  final double max;
  final double mid;
  final bool corrected; // user override

  const PriceItem({
    required this.id,
    required this.nameBn,
    required this.unit,
    required this.min,
    required this.max,
    required this.mid,
    this.corrected = false,
  });
}

class PriceData {
  final String reportDate;
  final String scrapedAt;
  final Map<String, PriceItem> retail;
  PriceData({required this.reportDate, required this.scrapedAt, required this.retail});
}

class PriceService {
  PriceData? _cache;

  Future<PriceData> load() async {
    if (_cache != null) return _cache!;
    Map<String, dynamic>? remote;
    try {
      final resp = await http
          .get(Uri.parse(AppConfig.priceFeedUrl))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        remote = json.decode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {
      // offline or feed not published yet -> bundled fallback
    }
    remote ??= json.decode(await rootBundle.loadString('assets/prices_fallback.json'))
        as Map<String, dynamic>;
    final corrections = await AppDb.priceCorrections();
    final retail = <String, PriceItem>{};
    final rawRetail = Map<String, dynamic>.from(remote['retail'] as Map);
    for (final e in rawRetail.entries) {
      final v = Map<String, dynamic>.from(e.value as Map);
      final override = corrections[e.key];
      retail[e.key] = PriceItem(
        id: e.key,
        nameBn: v['name_bn'] as String? ?? e.key,
        unit: v['unit'] as String? ?? 'kg',
        min: (v['min'] as num? ?? 0).toDouble(),
        max: (v['max'] as num? ?? 0).toDouble(),
        mid: (v['mid'] as num? ?? 0).toDouble(),
        corrected: override != null,
      );
      if (override != null) {
        final p = retail[e.key]!;
        retail[e.key] = PriceItem(
          id: p.id,
          nameBn: p.nameBn,
          unit: p.unit,
          min: override,
          max: override,
          mid: override,
          corrected: true,
        );
      }
    }
    _cache = PriceData(
      reportDate: remote['report_date'] as String? ?? '',
      scrapedAt: remote['scraped_at'] as String? ?? '',
      retail: retail,
    );
    return _cache!;
  }

  void invalidate() => _cache = null;
}

/// Protein cost ranking for the budget guide.
/// proteinPerUnit: grams of protein per price unit (kg / litre / piece / 4pcs).
class ProteinGuideEntry {
  final String labelEn;
  final String labelBn;
  final double proteinPerUnit;
  final PriceItem price;
  final double costPer30g;

  ProteinGuideEntry({
    required this.labelEn,
    required this.labelBn,
    required this.proteinPerUnit,
    required this.price,
  }) : costPer30g = price.mid <= 0 ? double.infinity : (price.mid / proteinPerUnit) * 30;
}

/// Curated guide items. proteinPerUnit uses typical values; DAM prices are live.
/// Whey/peanuts/soya are curated defaults (not in DAM data).
List<ProteinGuideEntry> buildProteinGuide(PriceData data) {
  ProteinGuideEntry e(String id, String en, String bn, double proteinPerUnit) {
    final p = data.retail[id];
    if (p == null) {
      throw StateError('missing price for $id');
    }
    return ProteinGuideEntry(labelEn: en, labelBn: bn, proteinPerUnit: proteinPerUnit, price: p);
  }

  PriceItem fixed(String id, String bn, String unit, double price) => PriceItem(
        id: id,
        nameBn: bn,
        unit: unit,
        min: price,
        max: price,
        mid: price,
      );

  final entries = <ProteinGuideEntry>[
    // egg: ~6.5g protein each; DAM unit is per piece
    e('egg_farm', 'Farm egg', 'ফার্মের ডিম', 6.5),
    // broiler: ~20g protein per 100g -> 200g per kg
    e('chicken_broiler', 'Broiler chicken', 'ব্রয়লার মুরগি', 200),
    // rui: ~18g per 100g -> 180g per kg (edible)
    e('fish_rui', 'Rui fish', 'রুই মাছ', 180),
    // pangas: ~16g per 100g
    e('fish_pangas', 'Pangas fish', 'পাঙ্গাস মাছ', 160),
    // tilapia: ~20g per 100g
    e('fish_tilapia', 'Tilapia', 'তেলাপিয়া', 200),
    // musur dal dry: ~24g per 100g -> 240g per kg
    e('lentil_coarse', 'Musur dal', 'মসুর ডাল', 240),
    // chickpea dry: ~19g per 100g
    e('chickpea', 'Chickpea', 'ছোলা', 190),
    // curated (not in DAM feed)
    ProteinGuideEntry(
      labelEn: 'Peanuts',
      labelBn: 'চিনাবাদাম',
      proteinPerUnit: 260, // 26g per 100g
      price: fixed('peanut', 'চিনাবাদাম', 'kg', 180),
    ),
    ProteinGuideEntry(
      labelEn: 'Soya chunks',
      labelBn: 'সয়া চাংক',
      proteinPerUnit: 520, // 52g per 100g dry
      price: fixed('soya', 'সয়া চাংক', 'kg', 220),
    ),
    ProteinGuideEntry(
      labelEn: 'Whey protein',
      labelBn: 'হোয়ে প্রোটিন',
      proteinPerUnit: 800, // 80g per 100g typical concentrate
      price: fixed('whey', 'হোয়ে প্রোটিন', 'kg', 9500),
    ),
  ];
  entries.sort((a, b) => a.costPer30g.compareTo(b.costPer30g));
  return entries;
}
