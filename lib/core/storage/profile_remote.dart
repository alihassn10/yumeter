import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/onboarding/domain/onboarding_answers.dart';
import '../supabase/supabase_config.dart';

/// The account's copy of the onboarding answers: one `profiles` row per user.
abstract interface class ProfileRemote {
  /// Null when the account has no profile yet.
  Future<OnboardingAnswers?> fetch(String userId);

  Future<void> upsert(String userId, OnboardingAnswers answers);
}

class SupabaseProfileRemote implements ProfileRemote {
  SupabaseProfileRemote(this._client);

  final SupabaseClient _client;

  @override
  Future<OnboardingAnswers?> fetch(String userId) async {
    final row =
        await _client.from('profiles').select().eq('id', userId).maybeSingle();
    return row == null ? null : profileFromRow(row);
  }

  @override
  Future<void> upsert(String userId, OnboardingAnswers answers) =>
      _client.from('profiles').upsert(profileToRow(userId, answers));
}

String? _date(DateTime? d) => d == null
    ? null
    : '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

Map<String, dynamic> profileToRow(String userId, OnboardingAnswers a) => {
      'id': userId,
      'sex': a.sex?.name,
      // A calendar date, so no time zone can move it to the day before.
      'birth_date': _date(a.birthDate),
      'height_cm': a.heightCm,
      'weight_kg': a.weightKg,
      'activity_level': a.activityLevel?.name,
      'goal': a.goal?.name,
      'target_weight_kg': a.targetWeightKg,
      'pace_kg_per_week': a.paceKgPerWeek,
      'diet_type': a.dietType.name,
      'units': a.units.name,
    };

/// Reads a row through [OnboardingAnswers.fromJson], which already tolerates
/// unknown enum names and missing fields.
OnboardingAnswers profileFromRow(Map<String, dynamic> row) =>
    OnboardingAnswers.fromJson({
      'sex': row['sex'],
      'birthDate': row['birth_date'],
      'heightCm': row['height_cm'],
      'weightKg': row['weight_kg'],
      'activityLevel': row['activity_level'],
      'goal': row['goal'],
      'targetWeightKg': row['target_weight_kg'],
      'paceKgPerWeek': row['pace_kg_per_week'],
      'dietType': row['diet_type'],
      'units': row['units'],
    });

final profileRemoteProvider = Provider<ProfileRemote>(
  (ref) => SupabaseProfileRemote(ref.watch(supabaseClientProvider)),
);
