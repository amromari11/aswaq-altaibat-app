import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  /// Sends an SMS OTP to [phone] (E.164 format, e.g. +9627XXXXXXXX).
  /// Requires phone auth to be enabled with an SMS provider configured in
  /// the Supabase dashboard (Authentication → Providers → Phone) — this
  /// call will fail until that's set up.
  Future<void> sendOtp(String phone) {
    return _client.auth.signInWithOtp(phone: phone);
  }

  Future<AuthResponse> verifyOtp({
    required String phone,
    required String token,
  }) {
    return _client.auth.verifyOTP(
      type: OtpType.sms,
      phone: phone,
      token: token,
    );
  }

  /// Requires Google enabled under Authentication → Providers in the
  /// Supabase dashboard (with a Google Cloud OAuth client ID/secret), plus
  /// platform redirect setup this app doesn't have yet: a custom URL scheme
  /// registered in `ios/Runner/Info.plist` and an intent-filter in
  /// `android/app/src/main/AndroidManifest.xml` so the OAuth redirect can
  /// return to the app. Without both, this call will fail or strand the
  /// user in the browser after sign-in.
  Future<bool> signInWithGoogle() {
    return _client.auth.signInWithOAuth(OAuthProvider.google);
  }

  Future<void> signOut() => _client.auth.signOut();
}
