import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../data/repositories/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

/// The signed-in user's saved phone (E.164), or null if none yet / signed
/// out. Re-fetches when the user changes; invalidate after saving.
final profilePhoneProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.watch(profileRepositoryProvider).fetchPhone(user.id);
});

/// Saves [phone] (already normalized) to the signed-in user's profile and
/// refreshes [profilePhoneProvider]. Throws [PhoneTakenException] if another
/// account has it, [StateError] if nobody is signed in.
Future<void> savePhone(WidgetRef ref, String phone) async {
  final user = ref.read(currentUserProvider);
  if (user == null) throw StateError('Not signed in');
  await ref.read(profileRepositoryProvider).updatePhone(user.id, phone);
  ref.invalidate(profilePhoneProvider);
}
