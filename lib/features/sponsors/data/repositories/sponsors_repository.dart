import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/sponsor_banner.dart';

class SponsorsRepository {
  SponsorsRepository(this._client);

  final SupabaseClient _client;

  Future<List<SponsorBanner>> fetchBanners({String placement = 'home'}) async {
    final rows = await _client
        .from('sponsors_banners')
        .select()
        .eq('is_active', true)
        .eq('placement', placement)
        .order('display_order');

    return (rows as List)
        .map((row) => SponsorBanner.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
