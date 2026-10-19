/// Nutrition math: BMR, targets, goal adjustments.
/// Mirrors lib/calorieCalculations.ts from the web app.
library;

enum Sex { male, female }

enum ActivityLevel { sedentary, light, moderate, active, veryActive }

enum GoalPath { gym, general }

enum GymPhase { bulk, cut, maintain }

const activityMultipliers = <ActivityLevel, double>{
  ActivityLevel.sedentary: 1.2,
  ActivityLevel.light: 1.375,
  ActivityLevel.moderate: 1.55,
  ActivityLevel.active: 1.725,
  ActivityLevel.veryActive: 1.9,
};

/// Mifflin-St Jeor BMR.
double bmr({required Sex sex, required double weightKg, required double heightCm, required int age}) {
  final s = sex == Sex.male ? 5 : -161;
  return 10 * weightKg + 6.25 * heightCm - 5 * age + s;
}

double tdee({required double bmrValue, required ActivityLevel activity}) =>
    bmrValue * activityMultipliers[activity]!;

/// Daily calorie target for a goal path + phase.
int calorieTarget({
  required GoalPath path,
  required double tdeeValue,
  GymPhase phase = GymPhase.maintain,
}) {
  switch (path) {
    case GoalPath.general:
      return tdeeValue.round();
    case GoalPath.gym:
      switch (phase) {
        case GymPhase.bulk:
          return (tdeeValue + 300).round();
        case GymPhase.cut:
          return (tdeeValue - 500).round();
        case GymPhase.maintain:
          return tdeeValue.round();
      }
  }
}

/// Daily protein target in grams.
int proteinTarget({
  required GoalPath path,
  required double weightKg,
  GymPhase phase = GymPhase.maintain,
}) {
  switch (path) {
    case GoalPath.general:
      return (weightKg * 1.2).round();
    case GoalPath.gym:
      switch (phase) {
        case GymPhase.bulk:
          return (weightKg * 1.8).round();
        case GymPhase.cut:
          return (weightKg * 2.2).round();
        case GymPhase.maintain:
          return (weightKg * 1.6).round();
      }
  }
}
