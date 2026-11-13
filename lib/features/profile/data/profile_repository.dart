import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sharegari/core/supabase/supabase_client_provider.dart';
import 'package:sharegari/features/profile/data/profile_models.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  /// Fetches the profile for a given user id.
  Future<UserProfile?> fetchProfile(String userId) async {
    final row = await _client
        .from('users')
        .select('id, name, full_name, phone, avatar_url, role, rating, rating_count, created_at, updated_at')
        .eq('id', userId)
        .maybeSingle();

    if (row == null) return null;
    return UserProfile.fromJson(row);
  }

  /// Updates full_name and/or phone on `public.users`.
  Future<void> updateProfile({
    required String userId,
    required String fullName,
    String? phone,
    String? avatarUrl,
  }) async {
    final updates = <String, dynamic>{
      'full_name': fullName.trim(),
      'name': fullName.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (phone != null) {
      updates['phone'] = phone.trim().isEmpty ? null : phone.trim();
    }
    if (avatarUrl != null) {
      updates['avatar_url'] = avatarUrl;
    }

    await _client.from('users').update(updates).eq('id', userId);
  }

  /// Uploads avatar image bytes to the "avatars" bucket inside `userId/avatar_<timestamp>.jpg`.
  /// Returns the public URL of the uploaded image.
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    final path = '$userId/$fileName';
    final mimeType = fileExtension == 'png'
        ? 'image/png'
        : fileExtension == 'webp'
            ? 'image/webp'
            : 'image/jpeg';

    await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: true,
          ),
        );

    final publicUrl = _client.storage.from('avatars').getPublicUrl(path);
    return publicUrl;
  }

  /// Calculates ride stats for the user from `ride_requests`.
  Future<UserRideStats> fetchRideStats(String userId) async {
    final rows = await _client
        .from('ride_requests')
        .select('status')
        .eq('rider_id', userId);

    int total = rows.length;
    int completed = 0;
    int cancelled = 0;

    for (final r in rows) {
      final status = r['status'] as String?;
      if (status == 'completed') {
        completed++;
      } else if (status == 'cancelled') {
        cancelled++;
      }
    }

    return UserRideStats(
      totalRequests: total,
      completedRides: completed,
      cancelledRides: cancelled,
    );
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(supabaseClientProvider)),
);
