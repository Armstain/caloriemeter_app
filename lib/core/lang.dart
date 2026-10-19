/// Minimal JSON-asset i18n. assets/l10n/en.json + bn.json.
/// Usage: `Lang.of(context).t('home.capture')`.
library;

import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

class Lang extends InheritedWidget {
  final String locale; // 'en' | 'bn'
  final Map<String, dynamic> strings;

  const Lang({super.key, required this.locale, required this.strings, required super.child});

  static Lang of(BuildContext context) {
    final lang = context.dependOnInheritedWidgetOfExactType<Lang>();
    assert(lang != null, 'Lang not found in widget tree');
    return lang!;
  }

  /// Dot-path lookup, e.g. t('home.capture'). Falls back to the key itself.
  String t(String path) {
    dynamic node = strings;
    for (final part in path.split('.')) {
      if (node is Map<String, dynamic> && node.containsKey(part)) {
        node = node[part];
      } else {
        return path;
      }
    }
    return node is String ? node : path;
  }

  /// Bengali-friendly number formatting: bn locale uses Bengali digits.
  String num(num n) {
    final s = n is int || n == n.roundToDouble() ? n.round().toString() : n.toStringAsFixed(1);
    if (locale != 'bn') return s;
    const en = '0123456789';
    const bn = '০১২৩৪৫৬৭৮৯';
    return s.split('').map((c) {
      final i = en.indexOf(c);
      return i >= 0 ? bn[i] : c;
    }).join();
  }

  @override
  bool updateShouldNotify(Lang old) => old.locale != locale || old.strings != strings;
}

Future<Map<String, dynamic>> loadStrings(String locale) async {
  final raw = await rootBundle.loadString('assets/l10n/$locale.json');
  return Map<String, dynamic>.from(json.decode(raw) as Map);
}
