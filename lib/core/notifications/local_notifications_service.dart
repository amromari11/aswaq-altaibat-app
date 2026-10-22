import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Abandoned-cart reminder, delivered as a local (device-scheduled)
/// notification rather than real push.
///
/// There's no backend push provider wired up yet (see
/// utils/notifications.py in the admin dashboard repo — still a logging
/// stub, no FCM/APNs keys), and the client-side cart is pure in-memory
/// state with nothing persisted server-side to detect abandonment from
/// outside the app anyway. A notification scheduled on-device the moment
/// the cart becomes non-empty covers the actual ask ("user leaves the app
/// / stops checkout for a while") without needing either of those —
/// the OS fires it at the scheduled time regardless of whether the app is
/// foregrounded, backgrounded, or killed.
///
/// Known limitation: scheduled local notifications on Android do not
/// survive a device reboot without a boot-completed receiver, which this
/// doesn't implement — low-stakes for a ~45 minute reminder window, but
/// worth knowing if that assumption ever changes.
class LocalNotificationsService {
  LocalNotificationsService._();

  static final LocalNotificationsService instance = LocalNotificationsService._();

  static const int _abandonedCartNotificationId = 1001;
  static const String _channelId = 'abandoned_cart';
  static const String _channelName = 'تذكير السلة';
  static const String _channelDescription = 'تذكير عند ترك منتجات في السلة دون إتمام الطلب';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    _initialized = true;
  }

  /// (Re)schedules the reminder for [delay] from now, replacing any
  /// previously-scheduled one — called every time the cart gains an item,
  /// so the clock always reflects the most recent cart activity.
  Future<void> scheduleAbandonedCartReminder({Duration delay = const Duration(minutes: 45)}) async {
    if (!_initialized) return;

    await _plugin.zonedSchedule(
      _abandonedCartNotificationId,
      'أسواق الطيبات',
      'أهلاً بك يا عميلنا، منتجاتك بانتظارك في أسواق الطيبات! أكمل طلبك الآن',
      tz.TZDateTime.now(tz.local).add(delay),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Inexact: avoids needing Android 12+'s separate "exact alarm"
      // permission for what's just a gentle, approximately-timed nudge.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Called when the cart empties (checkout completed, or cart cleared) —
  /// no point reminding someone about a cart that's no longer abandoned.
  Future<void> cancelAbandonedCartReminder() async {
    if (!_initialized) return;
    await _plugin.cancel(_abandonedCartNotificationId);
  }
}
