import 'package:flutter_test/flutter_test.dart';
import 'package:yumeter/features/onboarding/domain/goal_calculator.dart';
import 'package:yumeter/features/onboarding/domain/onboarding_answers.dart';

void main() {
  group('Mifflin-St Jeor', () {
    test('matches the published male formula', () {
      // 10(80) + 6.25(180) - 5(30) + 5 = 1780
      final plan = GoalCalculator.calculate(
        sex: Sex.male,
        age: 30,
        heightCm: 180,
        weightKg: 80,
        activityLevel: ActivityLevel.sedentary,
        goal: WeightGoal.maintain,
        paceKgPerWeek: 0,
        dietType: DietType.balanced,
      );
      expect(plan.bmr, 1780);
    });

    test('matches the published female formula', () {
      // 10(65) + 6.25(165) - 5(30) - 161 = 1370.25
      final plan = GoalCalculator.calculate(
        sex: Sex.female,
        age: 30,
        heightCm: 165,
        weightKg: 65,
        activityLevel: ActivityLevel.sedentary,
        goal: WeightGoal.maintain,
        paceKgPerWeek: 0,
        dietType: DietType.balanced,
      );
      expect(plan.bmr, 1370);
    });

    test('places the neutral option midway between the two forms', () {
      NutritionPlan planFor(Sex sex) => GoalCalculator.calculate(
            sex: sex,
            age: 30,
            heightCm: 175,
            weightKg: 70,
            activityLevel: ActivityLevel.sedentary,
            goal: WeightGoal.maintain,
            paceKgPerWeek: 0,
            dietType: DietType.balanced,
          );

      final other = planFor(Sex.other).bmr;
      expect(other, lessThan(planFor(Sex.male).bmr));
      expect(other, greaterThan(planFor(Sex.female).bmr));
    });
  });

  group('daily target', () {
    NutritionPlan planWith({
      required WeightGoal goal,
      double pace = 0.5,
      DietType diet = DietType.balanced,
    }) =>
        GoalCalculator.calculate(
          sex: Sex.male,
          age: 30,
          heightCm: 180,
          weightKg: 80,
          activityLevel: ActivityLevel.moderate,
          goal: goal,
          paceKgPerWeek: pace,
          dietType: diet,
        );

    test('applies the activity multiplier', () {
      expect(planWith(goal: WeightGoal.maintain).tdee, 2759); // 1780 * 1.55
    });

    test('maintaining eats at expenditure', () {
      final plan = planWith(goal: WeightGoal.maintain);
      expect(plan.calories, plan.tdee);
    });

    test('losing subtracts the weekly pace spread over seven days', () {
      // 0.5 kg/wk * 7700 kcal/kg / 7 = 550 kcal/day
      expect(planWith(goal: WeightGoal.lose).calories, 2209);
    });

    test('gaining adds the same shift', () {
      expect(planWith(goal: WeightGoal.gain).calories, 3309);
    });

    test('a negative pace is treated as a magnitude, not a direction', () {
      expect(
        planWith(goal: WeightGoal.lose, pace: -0.5).calories,
        planWith(goal: WeightGoal.lose, pace: 0.5).calories,
      );
    });

    test('splits macros to the diet ratios and back to the calorie total', () {
      final plan = planWith(goal: WeightGoal.lose);
      expect(plan.proteinGrams, 166);
      expect(plan.carbGrams, 221);
      expect(plan.fatGrams, 74);

      final fromMacros =
          plan.proteinGrams * 4 + plan.carbGrams * 4 + plan.fatGrams * 9;
      expect((fromMacros - plan.calories).abs(), lessThanOrEqualTo(10));
    });

    test('keto shifts energy from carbs into fat', () {
      final keto = planWith(goal: WeightGoal.maintain, diet: DietType.keto);
      final balanced = planWith(goal: WeightGoal.maintain);
      expect(keto.carbGrams, lessThan(balanced.carbGrams));
      expect(keto.fatGrams, greaterThan(balanced.fatGrams));
    });
  });

  group('safety floor', () {
    test('raises a target that an aggressive pace pushes too low', () {
      final plan = GoalCalculator.calculate(
        sex: Sex.female,
        age: 25,
        heightCm: 155,
        weightKg: 50,
        activityLevel: ActivityLevel.sedentary,
        goal: WeightGoal.lose,
        paceKgPerWeek: 1.0,
        dietType: DietType.balanced,
      );
      expect(plan.calories, 1200);
      expect(plan.clampedToFloor, isTrue);
    });

    test('leaves a reasonable target alone', () {
      final plan = GoalCalculator.calculate(
        sex: Sex.male,
        age: 30,
        heightCm: 180,
        weightKg: 80,
        activityLevel: ActivityLevel.moderate,
        goal: WeightGoal.lose,
        paceKgPerWeek: 0.5,
        dietType: DietType.balanced,
      );
      expect(plan.clampedToFloor, isFalse);
    });
  });

  group('tryCalculate', () {
    test('returns null while answers are incomplete', () {
      expect(GoalCalculator.tryCalculate(const OnboardingAnswers()), isNull);
      expect(
        GoalCalculator.tryCalculate(
          OnboardingAnswers(
            sex: Sex.male,
            birthDate: DateTime(1995, 6, 1),
            heightCm: 180,
            // No weight yet.
            activityLevel: ActivityLevel.moderate,
            goal: WeightGoal.lose,
          ),
        ),
        isNull,
      );
    });

    test('calculates once every required answer is present', () {
      final plan = GoalCalculator.tryCalculate(
        OnboardingAnswers(
          sex: Sex.male,
          birthDate: DateTime(1995, 6, 1),
          heightCm: 180,
          weightKg: 80,
          activityLevel: ActivityLevel.moderate,
          goal: WeightGoal.lose,
        ),
      );
      expect(plan, isNotNull);
      expect(plan!.calories, greaterThan(0));
    });
  });

  group('age', () {
    test('does not count a birthday that has not happened this year', () {
      final now = DateTime.now();
      final answers = OnboardingAnswers(
        birthDate: DateTime(now.year - 30, now.month, now.day)
            .add(const Duration(days: 1)),
      );
      expect(answers.age, 29);
    });

    test('counts a birthday that has already passed', () {
      final now = DateTime.now();
      final answers = OnboardingAnswers(
        birthDate: DateTime(now.year - 30, now.month, now.day)
            .subtract(const Duration(days: 1)),
      );
      expect(answers.age, 30);
    });
  });

  group('projectedGoalDate', () {
    test('scales the distance by the weekly pace', () {
      final from = DateTime(2026, 1, 1);
      final date = GoalCalculator.projectedGoalDate(
        currentWeightKg: 80,
        targetWeightKg: 75,
        paceKgPerWeek: 0.5,
        from: from,
      );
      // 5 kg at 0.5 kg/wk = 10 weeks.
      expect(date, from.add(const Duration(days: 70)));
    });

    test('is null when the target is already met or unset', () {
      expect(
        GoalCalculator.projectedGoalDate(
          currentWeightKg: 75,
          targetWeightKg: 75,
          paceKgPerWeek: 0.5,
        ),
        isNull,
      );
      expect(
        GoalCalculator.projectedGoalDate(
          currentWeightKg: 80,
          targetWeightKg: null,
          paceKgPerWeek: 0.5,
        ),
        isNull,
      );
    });

    test('is null when the pace is zero, rather than dividing by it', () {
      expect(
        GoalCalculator.projectedGoalDate(
          currentWeightKg: 80,
          targetWeightKg: 75,
          paceKgPerWeek: 0,
        ),
        isNull,
      );
    });
  });

  group('units', () {
    test('round-trips pounds and kilograms', () {
      expect(Units.kgToLb(Units.lbToKg(180)), closeTo(180, 1e-9));
    });

    test('converts centimetres to feet and inches', () {
      expect(Units.cmToFeetInches(180), (5, 11));
      expect(Units.feetInchesToCm(5, 11), closeTo(180.34, 0.01));
    });
  });
}
