import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase client settings for push notifications.
///
/// These identify the Firebase project to the app; like the Supabase anon key they are
/// public by design (access is controlled server-side), so they may be committed once
/// known. Until they are supplied the app simply runs without push — nothing else
/// depends on them.
///
/// Supply them at build time (`flutter run --dart-define-from-file=firebase.json`, with
/// FIREBASE_API_KEY, FIREBASE_PROJECT_ID, FIREBASE_MESSAGING_SENDER_ID,
/// FIREBASE_APP_ID_IOS and FIREBASE_APP_ID_ANDROID) or replace the defaults below.
/// Each Firebase app can have its own API key (and Google Cloud may restrict a key to one
/// platform): FIREBASE_API_KEY_ANDROID overrides FIREBASE_API_KEY on Android when set.
class PushConfig {
  const PushConfig({
    this.apiKey = const String.fromEnvironment('FIREBASE_API_KEY'),
    this.projectId = const String.fromEnvironment('FIREBASE_PROJECT_ID'),
    this.messagingSenderId = const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    this.iosAppId = const String.fromEnvironment('FIREBASE_APP_ID_IOS'),
    this.androidAppId = const String.fromEnvironment('FIREBASE_APP_ID_ANDROID'),
    this.androidApiKey = const String.fromEnvironment('FIREBASE_API_KEY_ANDROID'),
    this.iosBundleId = 'com.aswaqaltaibat.aswaqAltaibat',
  });

  final String apiKey;
  final String projectId;
  final String messagingSenderId;
  final String iosAppId;
  final String androidAppId;
  final String androidApiKey;
  final String iosBundleId;

  /// The options for [platform], or null when push isn't configured (or isn't
  /// supported there: web and desktop never register).
  FirebaseOptions? optionsFor(TargetPlatform platform, {bool isWeb = false}) {
    if (isWeb) return null;
    final String appId;
    var key = apiKey;
    switch (platform) {
      case TargetPlatform.iOS:
        appId = iosAppId;
      case TargetPlatform.android:
        appId = androidAppId;
        if (androidApiKey.trim().isNotEmpty) key = androidApiKey;
      default:
        return null;
    }
    if ([key, projectId, messagingSenderId, appId].any((v) => v.trim().isEmpty)) return null;
    return FirebaseOptions(
      apiKey: key,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      iosBundleId: platform == TargetPlatform.iOS ? iosBundleId : null,
    );
  }
}
