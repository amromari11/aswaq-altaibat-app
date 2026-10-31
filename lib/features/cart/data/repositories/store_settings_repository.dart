import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/fulfillment.dart';

class StoreSettingsRepository {
  StoreSettingsRepository(this._client);

  final SupabaseClient _client;

  /// The store's single settings row, or null if the server doesn't have
  /// pickup/scheduling yet (backend migration 015 not applied): checkout then
  /// offers delivery now only, exactly as before.
  Future<StoreSettings?> fetch() async {
    try {
      final rows = await _client.from('store_settings').select().limit(1);
      final list = rows as List;
      return list.isEmpty ? null : StoreSettings.fromJson(list.first as Map<String, dynamic>);
    } on PostgrestException {
      return null;
    }
  }
}
