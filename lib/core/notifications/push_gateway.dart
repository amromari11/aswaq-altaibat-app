import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'push_config.dart';

/// A notification that arrived while the app was open.
class PushMessage {
  const PushMessage({this.title, this.body});

  final String? title;
  final String? body;
}

/// The push provider, behind an interface so the registration logic can be tested
/// without Firebase.
abstract class PushGateway {
  /// Starts the provider. False when push isn't configured or isn't available here.
  Future<bool> init();

  /// Asks the user for permission to show notifications.
  Future<bool> requestPermission();

  /// This device's current registration token, or null if none could be obtained.
  Future<String?> token();

  Stream<String> get onTokenRefresh;

  Stream<PushMessage> get onForegroundMessage;
}

class FirebasePushGateway implements PushGateway {
  FirebasePushGateway({this.config = const PushConfig()});

  final PushConfig config;

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  Future<bool> init() async {
    final options = config.optionsFor(defaultTargetPlatform, isWeb: kIsWeb);
    if (options == null) return false;
    if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: options);
    // iOS shows a banner for a message that arrives while the app is open; Android doesn't,
    // so PushRegistrationService draws one there.
    await _messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
    return true;
  }

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> token() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // The FCM token needs Apple's token first; it can take a moment on a fresh install.
      for (var i = 0; i < 10 && await _messaging.getAPNSToken() == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (await _messaging.getAPNSToken() == null) return null; // e.g. the iOS simulator
    }
    // firebase_messaging 17 deprecates getToken/onTokenRefresh for register()/onRegistered, but
    // those hand back a Firebase Installation ID; the admin dashboard sends by the classic FCM
    // registration token (HTTP v1 `token`), which only these calls return.
    // ignore: deprecated_member_use
    return _messaging.getToken();
  }

  @override
  // ignore: deprecated_member_use
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<PushMessage> get onForegroundMessage => FirebaseMessaging.onMessage.map(
        (m) => PushMessage(title: m.notification?.title, body: m.notification?.body),
      );
}
