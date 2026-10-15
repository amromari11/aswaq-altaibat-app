import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The single Supabase client instance, available to every feature's
/// repositories via Riverpod instead of reaching for `Supabase.instance`
/// directly (keeps repositories testable/mockable).
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Streams the current auth state so widgets (e.g. the router redirect, the
/// account tab) can react to sign-in/sign-out/guest status.
final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

/// Convenience: the current signed-in user, or null for guests.
final currentUserProvider = Provider<User?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  ref.watch(authStateProvider);
  return client.auth.currentUser;
});
