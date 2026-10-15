import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../data/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

/// True once someone has chosen "تصفح كزائر" for this app session. Guests
/// can browse and add to cart; checkout still requires a real sign-in
/// (enforced where the order is actually placed, not here).
final isGuestProvider = StateProvider<bool>((ref) => false);
