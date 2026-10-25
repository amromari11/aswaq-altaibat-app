import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/saved_address.dart';

/// Mirrors the signed-in user's saved addresses to `user_addresses` (RLS:
/// own rows only, see backend supabase/007). Never called for guests —
/// [SavedAddressesNotifier] gates every call on a signed-in user first.
///
/// The one-default-per-user rule is enforced server-side by a trigger that
/// clears the flag on the user's other rows, so callers just write
/// `is_default: true` on the one they want.
class AddressesRepository {
  AddressesRepository(this._client);

  final SupabaseClient _client;

  Future<List<SavedAddress>> fetch(String userId) async {
    final rows = await _client
        .from('user_addresses')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: true);
    return [for (final row in rows as List) SavedAddress.fromJson(row as Map<String, dynamic>)];
  }

  Future<SavedAddress> insert(String userId, SavedAddress address) async {
    final row = await _client
        .from('user_addresses')
        .insert({...address.toRow(), 'user_id': userId})
        .select()
        .single();
    return SavedAddress.fromJson(row);
  }

  Future<SavedAddress> update(SavedAddress address) async {
    final row = await _client
        .from('user_addresses')
        .update(address.toRow())
        .eq('id', address.id)
        .select()
        .single();
    return SavedAddress.fromJson(row);
  }

  Future<void> setDefault(String id) {
    return _client.from('user_addresses').update({'is_default': true}).eq('id', id);
  }

  Future<void> delete(String id) {
    return _client.from('user_addresses').delete().eq('id', id);
  }
}
