import 'dart:math' as math;

import 'onboarding_answers.dart';

/// The daily targets shown on the plan reveal and driven into the dashboard.
class NutritionPlan {
  const NutritionPlan({
    required this.bmr,
    required this.tdee,
    required this.calories,
    required this.proteinGrams,
    required this.carbGrams,
    required this.fatGrams,
    required this.clampedToFloor,
  });

  /// Basal metabolic rate, kcal/day.
  final int bmr;

  /// Total daily energy expenditure, kcal/day.
  final int tdee;

  /// The daily calorie target after the goal adjustment.
  final int calories;

  final int proteinGrams;
  final int carbGrams;
  final int fatGrams;

  /// True when the requested deficit would have pushed the target below the
  /// safe floor, so the target was raised. Surface this rather than silently
  /// promising a pace the plan does not actually deliver.
  final bool clampedToFloor;
}

/// Turns onboarding answers into daily calorie and macro targets.
///
/// Energy expenditure uses Mifflin-St Jeor, which predicts resting metabolic
/// rate more closely than Harris-Benedict for most adults, multiplied by a
/// standard activity factor. These are population estimates, not measurements:
/// real intake needs adjusting against observed weight change.
abstract final class GoalCalculator {
  /// Energy in one kilogram of body fat, kcal. The usual 3500 kcal/lb figure.
  static const _kcalPerKgFat = 7700.0;

  /// Lowest daily intake the app will prescribe without clinical supervision.
  static const _floorMale = 1500;
  static const _floorFemale = 1200;

  /// Returns null until every field the formula needs has been answered.
  static NutritionPlan? tryCalculate(OnboardingAnswers a) {
    final age = a.age;
    final height = a.heightCm;
    final weight = a.weightKg;
    final sex = a.sex;
    final activity = a.activityLevel;
    final goal = a.goal;

    if (age == null ||
        height == null ||
        weight == null ||
        sex == null ||
        activity == null ||
        goal == null) {
      return null;
    }

    return calculate(
      sex: sex,
      age: age,
      heightCm: height,
      weightKg: weight,
      activityLevel: activity,
      goal: goal,
      paceKgPerWeek: a.paceKgPerWeek,
      dietType: a.dietType,
    );
  }

  static NutritionPlan calculate({
    required Sex sex,
    required int age,
    required double heightCm,
    required double weightKg,
    required ActivityLevel activityLevel,
    required WeightGoal goal,
    required double paceKgPerWeek,
    required DietType dietType,
  }) {
    // Mifflin-St Jeor: the sex term is the only difference between the two
    // published forms, so `other` sits midway rather than defaulting to either.
    final sexOffset = switch (sex) {
      Sex.male => 5.0,
      Sex.female => -161.0,
      Sex.other => -78.0,
    };
    final bmr = 10 * weightKg + 6.25 * heightCm - 5 * age + sexOffset;
    final tdee = bmr * activityLevel.multiplier;

    // Pace is a magnitude; the goal decides its sign.
    final dailyShift = paceKgPerWeek.abs() * _kcalPerKgFat / 7;
    final unclamped = switch (goal) {
      WeightGoal.lose => tdee - dailyShift,
      WeightGoal.gain => tdee + dailyShift,
      WeightGoal.maintain => tdee,
    };

    final floor = switch (sex) {
      Sex.male => _floorMale,
      Sex.female || Sex.other => _floorFemale,
    };
    final calories = math.max(unclamped, floor.toDouble()).round();

    return NutritionPlan(
      bmr: bmr.round(),
      tdee: tdee.round(),
      calories: calories,
      proteinGrams: (calories * dietType.proteinRatio / 4).round(),
      carbGrams: (calories * dietType.carbRatio / 4).round(),
      fatGrams: (calories * dietType.fatRatio / 9).round(),
      clampedToFloor: unclamped < floor,
    );
  }

  /// Projected date the target weight is reached at the chosen pace, or null
  /// when the goal is maintenance or the target is already met.
  static DateTime? projectedGoalDate({
    required double currentWeightKg,
    required double? targetWeightKg,
    required double paceKgPerWeek,
    DateTime? from,
  }) {
    final target = targetWeightKg;
    if (target == null || paceKgPerWeek <= 0) return null;

    final delta = (currentWeightKg - target).abs();
    if (delta < 0.1) return null;

    final weeks = delta / paceKgPerWeek;
    return (from ?? DateTime.now()).add(Duration(days: (weeks * 7).round()));
  }
}

/// Unit conversion for display. Storage stays metric everywhere.
abstract final class Units {
  static const kgPerLb = 0.45359237;
  static const cmPerInch = 2.54;

  static double lbToKg(double lb) => lb * kgPerLb;
  static double kgToLb(double kg) => kg / kgPerLb;
  static double inchToCm(double inches) => inches * cmPerInch;
  static double cmToInch(double cm) => cm / cmPerInch;

  /// Splits a height in centimetres into whole feet and inches.
  static (int feet, int inches) cmToFeetInches(double cm) {
    final totalInches = cmToInch(cm).round();
    return (totalInches ~/ 12, totalInches % 12);
  }

  static double feetInchesToCm(int feet, int inches) =>
      inchToCm(feet * 12 + inches.toDouble());
}
