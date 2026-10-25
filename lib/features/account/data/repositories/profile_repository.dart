import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown when another account already saved this phone number —
/// `profiles.phone_number` is unique.
class PhoneTakenException implements Exception {}

/// Reads/writes the signed-in user's own `profiles` row (RLS: own row only;
/// the row itself is created by the `handle_new_user` trigger on sign-up).
class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<String?> fetchPhone(String userId) async {
    final row = await _client.from('profiles').select('phone_number').eq('id', userId).maybeSingle();
    return row?['phone_number'] as String?;
  }

  /// [phone] must already be normalized E.164 (see `JordanPhone.normalize`).
  Future<void> updatePhone(String userId, String phone) async {
    try {
      await _client.from('profiles').update({'phone_number': phone}).eq('id', userId);
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw PhoneTakenException();
      rethrow;
    }
  }
}
