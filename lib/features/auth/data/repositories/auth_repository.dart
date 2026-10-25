import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  /// Deep link the OAuth flow returns to on iOS/Android. Must be registered
  /// in three places: Supabase dashboard → Authentication → URL
  /// Configuration → Redirect URLs, `CFBundleURLTypes` in
  /// ios/Runner/Info.plist, and an intent-filter in
  /// android/app/src/main/AndroidManifest.xml. supabase_flutter picks the
  /// link up itself (via app_links) and completes the session.
  static const mobileRedirectUrl = 'com.aswaqaltaibat.app://login-callback';

  /// Google is the only sign-in method (SMS OTP was dropped for cost).
  /// Requires Google enabled under Authentication → Providers in Supabase,
  /// with a Google Cloud OAuth client ID/secret.
  ///
  /// Returns once the browser has opened — the session arrives later via
  /// onAuthStateChange (main.dart's listener navigates on sign-in). On web
  /// the page itself redirects away and back, so in-memory state (a guest
  /// cart, the pending redirect) doesn't survive the round trip.
  Future<bool> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? Uri.base.origin : mobileRedirectUrl,
      authScreenLaunchMode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}
