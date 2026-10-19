/// Domain models. Entries keep `sharedMealId` / `cookedBy` / `correction`
/// fields from day one so shared-plate intelligence and the family kitchen
/// loop can be built later without a migration.
library;

class Macros {
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;

  const Macros({this.protein = 0, this.carbs = 0, this.fat = 0, this.fiber = 0});

  Macros operator +(Macros other) => Macros(
        protein: protein + other.protein,
        carbs: carbs + other.carbs,
        fat: fat + other.fat,
        fiber: fiber + other.fiber,
      );

  factory Macros.fromJson(Map<String, dynamic> j) => Macros(
        protein: (j['protein'] as num? ?? 0).toDouble(),
        carbs: (j['carbs'] as num? ?? 0).toDouble(),
        fat: (j['fat'] as num? ?? 0).toDouble(),
        fiber: (j['fiber'] as num? ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
      };
}

class AnalyzedFood {
  final String name;
  final double calories;
  final String quantity;
  final double confidence;
  final List<String> ingredients;
  final String? cookingMethod;
  final Macros macros;
  final String? category;
  final int? healthScore;

  const AnalyzedFood({
    required this.name,
    required this.calories,
    this.quantity = '',
    this.confidence = 0.7,
    this.ingredients = const [],
    this.cookingMethod,
    this.macros = const Macros(),
    this.category,
    this.healthScore,
  });

  factory AnalyzedFood.fromJson(Map<String, dynamic> j) => AnalyzedFood(
        name: (j['name'] as String?) ?? 'Unknown food',
        calories: (j['calories'] as num? ?? 0).toDouble(),
        quantity: (j['quantity'] as String?) ?? '',
        confidence: ((j['confidence'] as num? ?? 0.7).toDouble()).clamp(0.0, 1.0),
        ingredients: ((j['ingredients'] as List?) ?? []).map((e) => e.toString()).toList(),
        cookingMethod: j['cookingMethod'] as String?,
        macros: j['macros'] is Map
            ? Macros.fromJson(Map<String, dynamic>.from(j['macros'] as Map))
            : const Macros(),
        category: j['category'] as String?,
        healthScore: (j['healthScore'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'calories': calories,
        'quantity': quantity,
        'confidence': confidence,
        'ingredients': ingredients,
        'cookingMethod': cookingMethod,
        'macros': macros.toJson(),
        'category': category,
        'healthScore': healthScore,
      };
}

/// One logged meal.
class FoodEntry {
  final String id;
  final DateTime timestamp;
  final String date; // yyyy-MM-dd
  final String mealType; // breakfast|lunch|dinner|snack|sehri|iftar
  final List<AnalyzedFood> foods;
  final double totalCalories;
  final Macros totalMacros;
  final String? imagePath;
  final String? sharedMealId; // future: shared-plate intelligence
  final String? cookedBy; // future: family kitchen loop
  final Map<String, dynamic>? correction; // user correction -> training data

  const FoodEntry({
    required this.id,
    required this.timestamp,
    required this.date,
    required this.mealType,
    required this.foods,
    required this.totalCalories,
    required this.totalMacros,
    this.imagePath,
    this.sharedMealId,
    this.cookedBy,
    this.correction,
  });
}

/// A food in the local database.
class DbFood {
  final String id;
  final String nameEn;
  final String nameBn;
  final String category;
  final List<String> aliases;
  final double kcal100;
  final double protein100;
  final double carbs100;
  final double fat100;
  final double fiber100;
  final List<PortionUnit> portions;
  final String source; // fctb2013 | recipe | estimate

  const DbFood({
    required this.id,
    required this.nameEn,
    required this.nameBn,
    required this.category,
    this.aliases = const [],
    required this.kcal100,
    required this.protein100,
    required this.carbs100,
    required this.fat100,
    required this.fiber100,
    required this.portions,
    this.source = 'estimate',
  });

  factory DbFood.fromJson(Map<String, dynamic> j) => DbFood(
        id: j['id'] as String,
        nameEn: j['name_en'] as String,
        nameBn: (j['name_bn'] as String?) ?? '',
        category: (j['category'] as String?) ?? 'other',
        aliases: ((j['aliases'] as List?) ?? []).map((e) => e.toString()).toList(),
        kcal100: (j['kcal100'] as num).toDouble(),
        protein100: (j['protein100'] as num? ?? 0).toDouble(),
        carbs100: (j['carbs100'] as num? ?? 0).toDouble(),
        fat100: (j['fat100'] as num? ?? 0).toDouble(),
        fiber100: (j['fiber100'] as num? ?? 0).toDouble(),
        portions: ((j['portions'] as List?) ?? [])
            .map((p) => PortionUnit.fromJson(Map<String, dynamic>.from(p as Map)))
            .toList(),
        source: (j['source'] as String?) ?? 'estimate',
      );

  /// All searchable text, lowercased.
  String get searchText =>
      ('$nameEn $nameBn ${aliases.join(' ')}').toLowerCase();
}

class PortionUnit {
  final String unit; // plate | bati | piece | cup | spoon | glass
  final double grams;
  final String? labelEn;
  final String? labelBn;

  const PortionUnit({required this.unit, required this.grams, this.labelEn, this.labelBn});

  factory PortionUnit.fromJson(Map<String, dynamic> j) => PortionUnit(
        unit: j['unit'] as String,
        grams: (j['grams'] as num).toDouble(),
        labelEn: j['label_en'] as String?,
        labelBn: j['label_bn'] as String?,
      );
}
