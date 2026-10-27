import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../data/repositories/banners_repository.dart';
import '../../domain/entities/promo_banner.dart';

final bannersRepositoryProvider = Provider<BannersRepository>((ref) {
  return BannersRepository(ref.watch(supabaseClientProvider));
});

final promoBannersProvider = FutureProvider<List<PromoBanner>>((ref) {
  return ref.watch(bannersRepositoryProvider).fetchActive();
});
