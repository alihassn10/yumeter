import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../meals/data/meal_remote.dart';
import '../domain/meal_draft.dart';

/// Why a photo could not be turned into an estimate, so the screen can say
/// something useful and offer the right way forward.
enum AnalysisFailureKind {
  /// The model found no food or drink in the photo.
  notFood,

  /// The vision service is rate-limited or overloaded; trying again shortly
  /// usually works.
  rateLimited,

  /// No connection, so neither the upload nor the analysis can run.
  offline,

  /// Anything else on the server side.
  failed,
}

class AnalysisFailure implements Exception {
  const AnalysisFailure(this.kind);

  final AnalysisFailureKind kind;

  @override
  String toString() => 'AnalysisFailure(${kind.name})';
}

/// Moves a meal photo to the account and asks the server what is on it.
abstract interface class MealPhotoService {
  /// Uploads [bytes] for meal [mealId] and returns the storage path.
  Future<String> upload({
    required String userId,
    required String mealId,
    required Uint8List bytes,
    required String extension,
  });

  /// Runs the `analyze-meal` function on an uploaded photo.
  Future<MealDraft> analyze(String photoPath);

  /// Removes a photo that will not be saved with a meal.
  Future<void> remove(String photoPath);

  /// A short-lived link to view a meal's photo. The bucket is private, so
  /// photos are only ever shown through signed links like this.
  Future<String> viewUrl(String photoPath);
}

class SupabaseMealPhotoService implements MealPhotoService {
  SupabaseMealPhotoService(this._client);

  final SupabaseClient _client;

  static const _mimeTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'heic': 'image/heic',
    'heif': 'image/heif',
  };

  @override
  Future<String> upload({
    required String userId,
    required String mealId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final ext = extension.toLowerCase();
    // The bucket's policies only accept paths inside the user's own folder.
    final path = '$userId/$mealId.$ext';
    try {
      await _client.storage.from(mealPhotosBucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: _mimeTypes[ext] ?? 'image/jpeg',
              // A retake for the same meal replaces the earlier photo.
              upsert: true,
            ),
          );
      return path;
    } on StorageException {
      throw const AnalysisFailure(AnalysisFailureKind.failed);
    } on Exception {
      throw const AnalysisFailure(AnalysisFailureKind.offline);
    }
  }

  @override
  Future<MealDraft> analyze(String photoPath) async {
    try {
      final res = await _client.functions.invoke(
        'analyze-meal',
        body: {'photo_path': photoPath},
      );
      final data = res.data;
      if (data is! Map<String, dynamic>) {
        throw const AnalysisFailure(AnalysisFailureKind.failed);
      }
      return MealDraft.fromAnalysis(data);
    } on FunctionException catch (e) {
      throw AnalysisFailure(switch (e.status) {
        422 => AnalysisFailureKind.notFood,
        429 || 503 => AnalysisFailureKind.rateLimited,
        _ => AnalysisFailureKind.failed,
      });
    } on AnalysisFailure {
      rethrow;
    } on Exception {
      throw const AnalysisFailure(AnalysisFailureKind.offline);
    }
  }

  @override
  Future<void> remove(String photoPath) async {
    await _client.storage.from(mealPhotosBucket).remove([photoPath]);
  }

  @override
  Future<String> viewUrl(String photoPath) => _client.storage
      .from(mealPhotosBucket)
      .createSignedUrl(photoPath, const Duration(hours: 1).inSeconds);
}

final mealPhotoServiceProvider = Provider<MealPhotoService>(
  (ref) => SupabaseMealPhotoService(ref.watch(supabaseClientProvider)),
);
