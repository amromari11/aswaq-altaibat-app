import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/promo_banner.dart';

class BannersRepository {
  BannersRepository(this._client);

  final SupabaseClient _client;

  /// Active banners in the order the admin arranged them. (RLS already hides
  /// inactive ones; the filter keeps that true if the policy ever changes.)
  Future<List<PromoBanner>> fetchActive() async {
    final rows = await _client
        .from('banners')
        .select()
        .eq('is_active', true)
        .order('display_order', ascending: true)
        .order('created_at', ascending: true);

    return (rows as List)
        .map((row) => PromoBanner.fromJson(row as Map<String, dynamic>))
        .where((b) => b.imageUrl.isNotEmpty)
        .toList();
  }
}
