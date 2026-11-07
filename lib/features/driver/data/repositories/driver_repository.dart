import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/driver_order.dart';
import '../../domain/entities/driver_profile.dart';

/// A driver action the database refused, with a message to show the driver.
class DriverActionException implements Exception {
  const DriverActionException(this.messageAr);

  final String messageAr;

  @override
  String toString() => messageAr;
}

/// Everything driver mode needs from Supabase. All writes go through the
/// `driver_*` database functions (backend supabase/019): they check that the
/// caller is a driver and that the order is theirs, so RLS on `orders` stays
/// closed. The customer's tracking screen updates by itself on each status
/// change (the 009 broadcast trigger).
class DriverRepository {
  DriverRepository(this._client);

  final SupabaseClient _client;

  /// The user's role and availability (own row, readable under RLS). Before
  /// 019 is applied the columns don't exist: everyone is then a customer.
  Future<DriverProfile> fetchProfile(String userId) async {
    try {
      final row = await _client.from('profiles').select('role, is_available, full_name').eq('id', userId).maybeSingle();
      if (row == null) return DriverProfile.customer;
      return DriverProfile(
        role: (row['role'] as String?) ?? 'customer',
        isAvailable: row['is_available'] as bool? ?? false,
        fullName: row['full_name'] as String?,
      );
    } on PostgrestException catch (e) {
      if (e.code == '42703') return DriverProfile.customer; // undefined column
      rethrow;
    }
  }

  /// "متاح للتوصيل" — returns the state the database stored.
  Future<bool> setAvailable(bool available) => _call(() async {
        final result = await _client.rpc('driver_set_available', params: {'p_available': available});
        return result as bool? ?? available;
      });

  /// My orders that aren't delivered or cancelled, the one on the road first.
  Future<List<DriverOrder>> fetchAssignedOrders() => _call(() async {
        final rows = await _client.rpc('driver_assigned_orders');
        return [for (final row in (rows as List).cast<Map<String, dynamic>>()) DriverOrder.fromJson(row)];
      });

  /// "استلام الطلب" — the order goes out for delivery.
  Future<void> pickUp(String orderId) => _call(() => _client.rpc('driver_pick_up', params: {'p_order_id': orderId}));

  /// "تم التسليم" — delivered, paid, loyalty points awarded.
  Future<DeliveryResult> markDelivered(String orderId) => _call(() async {
        final json = await _client.rpc('driver_mark_delivered', params: {'p_order_id': orderId});
        return DeliveryResult.fromJson(Map<String, dynamic>.from(json as Map));
      });

  /// Fires whenever an order is assigned to / taken from [driverId] or changes
  /// status (019's `driver:<id>` ping), and on every (re)connect so a change
  /// missed while offline is caught up.
  Stream<void> changes(String driverId) {
    late final StreamController<void> controller;
    RealtimeChannel? channel;
    controller = StreamController<void>(
      onListen: () {
        channel = _client
            .channel('driver:$driverId')
            .onBroadcast(event: 'orders', callback: (_) => controller.add(null))
            .subscribe((status, _) {
          if (status == RealtimeSubscribeStatus.subscribed) controller.add(null);
        });
      },
      onCancel: () async {
        final active = channel;
        if (active != null) await _client.removeChannel(active);
      },
    );
    return controller.stream;
  }

  Future<T> _call<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PostgrestException catch (e) {
      throw DriverActionException(messageFor(e.message));
    }
  }

  /// Arabic text for the error codes raised by the 019 functions.
  static String messageFor(String code) {
    switch (code) {
      case 'not_signed_in':
        return 'سجّل الدخول أولاً.';
      case 'not_a_driver':
        return 'هذا الحساب غير مسجّل كسائق.';
      case 'order_not_found':
        return 'هذا الطلب لم يعد مسنداً إليك.';
      case 'not_a_delivery':
        return 'هذا طلب استلام من الفرع وليس توصيلاً.';
      case 'invalid_status':
        return 'لا يمكن تنفيذ هذا الإجراء في حالة الطلب الحالية.';
      default:
        return 'تعذّر تنفيذ الطلب، حاول مرة أخرى.';
    }
  }
}
