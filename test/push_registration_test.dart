import 'dart:async';

import 'package:aswaq_altaibat/core/notifications/push_config.dart';
import 'package:aswaq_altaibat/core/notifications/push_gateway.dart';
import 'package:aswaq_altaibat/core/notifications/push_registration_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeGateway implements PushGateway {
  FakeGateway({this.configured = true, this.permission = true, this.currentToken = 'token-aaaaaaaaaaaaaaaaaaaaaa'});

  final bool configured;
  final bool permission;
  String? currentToken;
  Object? failWith;
  final refresh = StreamController<String>.broadcast();
  final foreground = StreamController<PushMessage>.broadcast();
  final calls = <String>[];

  @override
  Future<bool> init() async {
    calls.add('init');
    if (failWith != null) throw failWith!;
    return configured;
  }

  @override
  Future<bool> requestPermission() async {
    calls.add('permission');
    return permission;
  }

  @override
  Future<String?> token() async {
    calls.add('token');
    return currentToken;
  }

  @override
  Stream<String> get onTokenRefresh => refresh.stream;

  @override
  Stream<PushMessage> get onForegroundMessage => foreground.stream;
}

class Recorder {
  final stored = <(String, String)>[];
  bool failing = false;

  Future<void> call(String token, String platform) async {
    if (failing) throw Exception('network down');
    stored.add((token, platform));
  }
}

PushRegistrationService make(FakeGateway gateway, Recorder recorder,
    {String platform = 'android', void Function(PushMessage)? showForeground}) {
  return PushRegistrationService(
    gateway: gateway,
    register: recorder.call,
    platform: platform,
    showForeground: showForeground,
  );
}

void main() {
  group('registration on startup', () {
    test('a configured device with permission stores its token and platform', () async {
      final rec = Recorder();
      final service = make(FakeGateway(), rec, platform: 'ios');
      await service.start();
      expect(rec.stored, [('token-aaaaaaaaaaaaaaaaaaaaaa', 'ios')]);
      expect(service.token, 'token-aaaaaaaaaaaaaaaaaaaaaa');
    });

    test('without Firebase settings nothing is asked or stored', () async {
      final gateway = FakeGateway(configured: false);
      final rec = Recorder();
      await make(gateway, rec).start();
      expect(rec.stored, isEmpty);
      expect(gateway.calls, ['init'], reason: 'no permission prompt when push is not set up');
    });

    test('a declined permission stores nothing', () async {
      final gateway = FakeGateway(permission: false);
      final rec = Recorder();
      await make(gateway, rec).start();
      expect(rec.stored, isEmpty);
      expect(gateway.calls, ['init', 'permission']);
    });

    test('no token available yet (e.g. the iOS simulator) stores nothing and does not fail', () async {
      final rec = Recorder();
      await make(FakeGateway(currentToken: null), rec).start();
      expect(rec.stored, isEmpty);
    });

    test('starting twice registers once', () async {
      final rec = Recorder();
      final service = make(FakeGateway(), rec);
      await service.start();
      await service.start();
      expect(rec.stored.length, 1);
    });

    test('a provider that throws never escapes', () async {
      final gateway = FakeGateway()..failWith = StateError('firebase exploded');
      final rec = Recorder();
      await expectLater(make(gateway, rec).start(), completes);
      expect(rec.stored, isEmpty);
    });

    test('a failing network call never escapes either', () async {
      final rec = Recorder()..failing = true;
      await expectLater(make(FakeGateway(), rec).start(), completes);
    });
  });

  group('keeping the registration current', () {
    test('a refreshed token is stored', () async {
      final gateway = FakeGateway();
      final rec = Recorder();
      final service = make(gateway, rec);
      await service.start();
      gateway.refresh.add('token-bbbbbbbbbbbbbbbbbbbbbb');
      await Future<void>.delayed(Duration.zero);
      expect(rec.stored.last.$1, 'token-bbbbbbbbbbbbbbbbbbbbbb');
      expect(service.token, 'token-bbbbbbbbbbbbbbbbbbbbbb');
    });

    test('signing in or out re-sends the same token so the server can move the device', () async {
      final rec = Recorder();
      final service = make(FakeGateway(), rec);
      await service.start();
      await service.refreshRegistration();
      expect(rec.stored.map((e) => e.$1).toSet(), {'token-aaaaaaaaaaaaaaaaaaaaaa'});
      expect(rec.stored.length, 2);
    });

    test('refreshing before there is a token does nothing', () async {
      final rec = Recorder();
      await make(FakeGateway(configured: false), rec).refreshRegistration();
      expect(rec.stored, isEmpty);
    });

    test('a failed refresh can be retried on the next sign-in change', () async {
      final rec = Recorder();
      final service = make(FakeGateway(), rec);
      await service.start();
      rec.failing = true;
      await service.refreshRegistration();
      rec.failing = false;
      await service.refreshRegistration();
      expect(rec.stored.length, 2);
    });

    test('after dispose, token refreshes are ignored', () async {
      final gateway = FakeGateway();
      final rec = Recorder();
      final service = make(gateway, rec);
      await service.start();
      service.dispose();
      gateway.refresh.add('token-cccccccccccccccccccccc');
      await Future<void>.delayed(Duration.zero);
      expect(rec.stored.length, 1);
    });
  });

  group('a push that arrives while the app is open', () {
    test('Android draws it itself', () async {
      final gateway = FakeGateway();
      final shown = <PushMessage>[];
      await make(gateway, Recorder(), showForeground: shown.add).start();
      gateway.foreground.add(const PushMessage(title: 'عرض', body: 'خصم'));
      await Future<void>.delayed(Duration.zero);
      expect(shown.single.title, 'عرض');
    });

    test('iOS shows it natively, so the app does not draw a second one', () async {
      final gateway = FakeGateway();
      final shown = <PushMessage>[];
      await make(gateway, Recorder(), platform: 'ios', showForeground: shown.add).start();
      gateway.foreground.add(const PushMessage(title: 'عرض', body: 'خصم'));
      await Future<void>.delayed(Duration.zero);
      expect(shown, isEmpty);
    });
  });

  group('Firebase settings', () {
    const complete = PushConfig(
      apiKey: 'key',
      projectId: 'aswaq',
      messagingSenderId: '123',
      iosAppId: '1:123:ios:abc',
      androidAppId: '1:123:android:def',
    );

    test('each platform gets its own app id', () {
      expect(complete.optionsFor(TargetPlatform.iOS)!.appId, '1:123:ios:abc');
      expect(complete.optionsFor(TargetPlatform.android)!.appId, '1:123:android:def');
      expect(complete.optionsFor(TargetPlatform.iOS)!.iosBundleId, 'com.aswaqaltaibat.aswaqAltaibat');
      expect(complete.optionsFor(TargetPlatform.android)!.iosBundleId, isNull);
    });

    test('web and desktop never register', () {
      expect(complete.optionsFor(TargetPlatform.android, isWeb: true), isNull);
      expect(complete.optionsFor(TargetPlatform.macOS), isNull);
    });

    test('any missing value switches push off instead of crashing', () {
      expect(const PushConfig(apiKey: '', projectId: 'a', messagingSenderId: '1', iosAppId: 'x').optionsFor(TargetPlatform.iOS), isNull);
      expect(const PushConfig(apiKey: 'k', projectId: 'a', messagingSenderId: '1', iosAppId: ' ').optionsFor(TargetPlatform.iOS), isNull);
      expect(const PushConfig(apiKey: 'k', projectId: 'a', messagingSenderId: '1', iosAppId: 'x').optionsFor(TargetPlatform.android), isNull,
          reason: 'an iOS app id does not configure Android');

      const both = PushConfig(
        apiKey: 'ios-key', androidApiKey: 'droid-key', projectId: 'a', messagingSenderId: '1', iosAppId: 'i', androidAppId: 'd');
      expect(both.optionsFor(TargetPlatform.android)!.apiKey, 'droid-key');
      expect(both.optionsFor(TargetPlatform.iOS)!.apiKey, 'ios-key');
      expect(const PushConfig(apiKey: 'shared', projectId: 'a', messagingSenderId: '1', androidAppId: 'd').optionsFor(TargetPlatform.android)!.apiKey, 'shared');
    });

    test('the default (no --dart-define) is unconfigured', () {
      expect(const PushConfig().optionsFor(TargetPlatform.iOS), isNull);
    });
  });
}
