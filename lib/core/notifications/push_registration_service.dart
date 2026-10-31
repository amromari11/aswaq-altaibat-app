import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase/supabase_providers.dart';
import 'local_notifications_service.dart';
import 'push_gateway.dart';

/// Stores this device's push token with the shop (`register_push_token`).
typedef PushTokenRegistrar = Future<void> Function(String token, String platform);

final pushGatewayProvider = Provider<PushGateway>((ref) => FirebasePushGateway());

final pushTokenRegistrarProvider = Provider<PushTokenRegistrar>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return (token, platform) => client.rpc('register_push_token', params: {
        'p_token': token,
        'p_platform': platform,
      });
});

final pushRegistrationServiceProvider = Provider<PushRegistrationService>((ref) {
  final service = PushRegistrationService(
    gateway: ref.watch(pushGatewayProvider),
    register: ref.watch(pushTokenRegistrarProvider),
    platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
    showForeground: (m) => LocalNotificationsService.instance.showPromotion(m.title, m.body),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Registers the device for push on startup and keeps the registration current.
///
/// Guests and signed-in customers both register (the server attaches the account, if
/// any). Nothing here may ever break the app: a missing Firebase config, a denied
/// permission or a network error just means no push for this session.
class PushRegistrationService {
  PushRegistrationService({
    required this.gateway,
    required this.register,
    required this.platform,
    this.showForeground,
  });

  final PushGateway gateway;
  final PushTokenRegistrar register;

  /// 'ios' or 'android', stored with the token.
  final String platform;

  /// Draws a banner for a push that arrives while the app is open (Android only: iOS does
  /// it itself).
  final void Function(PushMessage message)? showForeground;

  String? _token;
  bool _started = false;
  final _subscriptions = <StreamSubscription<Object?>>[];

  /// The token currently registered, if any.
  String? get token => _token;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      if (!await gateway.init()) return;
      if (!await gateway.requestPermission()) return;

      _subscriptions.add(gateway.onTokenRefresh.listen((t) => _store(t)));
      if (platform == 'android' && showForeground != null) {
        _subscriptions.add(gateway.onForegroundMessage.listen(showForeground));
      }

      final token = await gateway.token();
      if (token != null) await _store(token);
    } catch (e) {
      debugPrint('Push registration skipped: $e');
    }
  }

  /// Re-sends the current token — call after sign-in or sign-out so the server moves the
  /// device to the right account (or back to a guest).
  Future<void> refreshRegistration() async {
    final token = _token;
    if (token != null) await _store(token);
  }

  Future<void> _store(String token) async {
    _token = token;
    try {
      await register(token, platform);
    } catch (e) {
      debugPrint('Could not register the push token: $e');
    }
  }

  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
  }
}
