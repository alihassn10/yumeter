/// Biological sex, used only to pick the Mifflin-St Jeor constant. `other`
/// averages the male and female offsets rather than guessing either way.
enum Sex { male, female, other }

/// Training frequency, mapped to the standard TDEE activity multipliers.
enum ActivityLevel {
  sedentary(1.2, 'Sedentary', 'Little or no exercise'),
  light(1.375, 'Lightly active', '1-2 workouts a week'),
  moderate(1.55, 'Moderately active', '3-4 workouts a week'),
  veryActive(1.725, 'Very active', '5-6 workouts a week'),
  extraActive(1.9, 'Extra active', 'Daily training or physical job');

  const ActivityLevel(this.multiplier, this.label, this.description);

  final double multiplier;
  final String label;
  final String description;
}

enum WeightGoal {
  lose('Lose weight', 'A steady calorie deficit'),
  maintain('Maintain weight', 'Hold your current weight'),
  gain('Build muscle', 'A controlled calorie surplus');

  const WeightGoal(this.label, this.description);

  final String label;
  final String description;
}

/// Macro splits as fractions of total energy, in protein/carb/fat order. Each
/// set sums to 1.0.
enum DietType {
  balanced('Balanced', 'A bit of everything', 0.30, 0.40, 0.30),
  highProtein('High protein', 'Prioritise muscle retention', 0.35, 0.35, 0.30),
  lowCarb('Low carb', 'Fewer carbs, more fat', 0.35, 0.20, 0.45),
  keto('Keto', 'Very low carb', 0.25, 0.05, 0.70),
  vegetarian('Vegetarian', 'No meat or fish', 0.25, 0.45, 0.30);

  const DietType(
    this.label,
    this.description,
    this.proteinRatio,
    this.carbRatio,
    this.fatRatio,
  );

  final String label;
  final String description;
  final double proteinRatio;
  final double carbRatio;
  final double fatRatio;
}

enum UnitSystem { metric, imperial }

/// Everything the onboarding quiz collects.
///
/// Measurements are stored canonically in metric (cm, kg) whatever the user
/// entered, so the calculator never has to care about [units]; that flag only
/// drives display.
class OnboardingAnswers {
  const OnboardingAnswers({
    this.sex,
    this.birthDate,
    this.heightCm,
    this.weightKg,
    this.activityLevel,
    this.goal,
    this.targetWeightKg,
    this.paceKgPerWeek = 0.5,
    this.dietType = DietType.balanced,
    this.units = UnitSystem.metric,
  });

  final Sex? sex;
  final DateTime? birthDate;
  final double? heightCm;
  final double? weightKg;
  final ActivityLevel? activityLevel;
  final WeightGoal? goal;
  final double? targetWeightKg;

  /// How fast the user wants to move, always a positive magnitude. The
  /// direction comes from [goal].
  final double paceKgPerWeek;

  final DietType dietType;
  final UnitSystem units;

  /// Age in whole years at today's date, or null before a birth date is set.
  int? get age {
    final birth = birthDate;
    if (birth == null) return null;
    final now = DateTime.now();
    var years = now.year - birth.year;
    // Subtract a year when this year's birthday has not come round yet.
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      years--;
    }
    return years;
  }

  OnboardingAnswers copyWith({
    Sex? sex,
    DateTime? birthDate,
    double? heightCm,
    double? weightKg,
    ActivityLevel? activityLevel,
    WeightGoal? goal,
    double? targetWeightKg,
    double? paceKgPerWeek,
    DietType? dietType,
    UnitSystem? units,
  }) {
    return OnboardingAnswers(
      sex: sex ?? this.sex,
      birthDate: birthDate ?? this.birthDate,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      activityLevel: activityLevel ?? this.activityLevel,
      goal: goal ?? this.goal,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      paceKgPerWeek: paceKgPerWeek ?? this.paceKgPerWeek,
      dietType: dietType ?? this.dietType,
      units: units ?? this.units,
    );
  }
}
