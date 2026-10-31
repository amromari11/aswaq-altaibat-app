import 'dart:convert';

import 'package:aswaq_altaibat/features/cart/data/repositories/checkout_repository.dart';
import 'package:aswaq_altaibat/features/cart/domain/entities/cart_item.dart';
import 'package:aswaq_altaibat/features/cart/domain/entities/fulfillment.dart';
import 'package:aswaq_altaibat/features/home/domain/entities/product.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _milk = Product(id: 'aaaaaaaa-0000-0000-0000-000000000001', categoryId: 'c', name: 'Milk', nameAr: 'حليب', price: 2.5);
const _cheese = Product(id: 'aaaaaaaa-0000-0000-0000-000000000002', categoryId: 'c', name: 'Cheese', nameAr: 'جبنة', price: 4, discountPrice: 3.25);

/// A client whose HTTP layer is [handler] — nothing leaves the test.
CheckoutRepository _repo(Future<http.Response> Function(http.Request) handler) {
  final client = SupabaseClient(
    'http://localhost:54321',
    'test-anon-key',
    httpClient: MockClient(handler),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  return CheckoutRepository(client);
}

Future<String> _place(CheckoutRepository repo) => repo.placeOrder(
      customerName: 'سالم أحمد',
      customerPhone: '+962791234567',
      items: const [CartItem(product: _milk, quantity: 2), CartItem(product: _cheese, quantity: 1)],
      deliveryAddress: 'الزرقاء الجديدة - شارع الجيش',
      zoneId: 'zone-1',
      addressId: 'addr-1',
      deliveryLat: 32.07,
      deliveryLng: 36.09,
      notes: 'اتصل عند الوصول',
    );

void main() {
  test('calls place_order with ids and quantities only — never prices or totals', () async {
    late http.Request seen;
    final repo = _repo((request) async {
      seen = request;
      return http.Response(jsonEncode('11111111-2222-3333-4444-555555555555'), 200,
          headers: {'content-type': 'application/json'}, request: request);
    });

    final id = await _place(repo);

    expect(id, '11111111-2222-3333-4444-555555555555');
    expect(seen.method, 'POST');
    expect(seen.url.path, '/rest/v1/rpc/place_order');
    final body = jsonDecode(seen.body) as Map<String, dynamic>;
    expect(body['p_customer_name'], 'سالم أحمد');
    expect(body['p_customer_phone'], '+962791234567');
    expect(body['p_zone_id'], 'zone-1');
    expect(body['p_address_id'], 'addr-1');
    expect(body['p_delivery_lat'], 32.07);
    expect(body['p_notes'], 'اتصل عند الوصول');
    expect(body['p_items'], [
      {'product_id': _milk.id, 'quantity': 2},
      {'product_id': _cheese.id, 'quantity': 1},
    ]);
    // The database prices the order; the phone must not be able to dictate it.
    final sent = seen.body;
    for (final forbidden in ['price', 'total', 'fee', 'subtotal']) {
      expect(sent.contains(forbidden), isFalse, reason: 'request body mentions "$forbidden"');
    }
  });

  test('a refusal from place_order (SQLSTATE P0001) becomes OrderRejectedException with its code', () async {
    final repo = _repo((request) async => http.Response(
          jsonEncode({'code': 'P0001', 'details': null, 'hint': null, 'message': 'below_minimum'}),
          400,
          headers: {'content-type': 'application/json'},
          request: request,
        ));

    await expectLater(
      _place(repo),
      throwsA(isA<OrderRejectedException>().having((e) => e.code, 'code', 'below_minimum')),
    );
  });

  test('any other server error is not mistaken for a rejection', () async {
    final repo = _repo((request) async => http.Response(
          jsonEncode({'code': '42501', 'message': 'permission denied for function place_order'}),
          403,
          headers: {'content-type': 'application/json'},
          request: request,
        ));

    await expectLater(_place(repo), throwsA(isA<PostgrestException>()));
  });

  group('delivery or pickup, now or later (backend 015)', () {
    Future<Map<String, dynamic>> sent(Future<String> Function(CheckoutRepository repo) place) async {
      late http.Request seen;
      final repo = _repo((request) async {
        seen = request;
        return http.Response(jsonEncode('11111111-2222-3333-4444-555555555555'), 200,
            headers: {'content-type': 'application/json'}, request: request);
      });
      await place(repo);
      return jsonDecode(seen.body) as Map<String, dynamic>;
    }

    test('delivery now sends neither new argument, so an older server still accepts it', () async {
      final body = await sent(_place);
      expect(body.containsKey('p_order_type'), isFalse);
      expect(body.containsKey('p_scheduled_time'), isFalse);
    });

    test('pickup at a slot: type and the slot start (UTC), no address or zone', () async {
      final body = await sent((repo) => repo.placeOrder(
            customerName: 'سالم أحمد',
            customerPhone: '+962791234567',
            items: const [CartItem(product: _milk, quantity: 1)],
            orderType: OrderType.pickup,
            scheduledTime: DateTime.utc(2026, 11, 3, 7),
          ));
      expect(body['p_order_type'], 'pickup');
      expect(body['p_scheduled_time'], '2026-11-03T07:00:00.000Z');
      expect(body['p_delivery_address'], isNull);
      expect(body['p_zone_id'], isNull);
    });

    test('a slot given in local time is sent as the same instant in UTC', () async {
      final local = DateTime.utc(2026, 11, 3, 7).toLocal();
      final body = await sent((repo) => repo.placeOrder(
            customerName: 'سالم أحمد',
            customerPhone: '+962791234567',
            items: const [CartItem(product: _milk, quantity: 1)],
            deliveryAddress: 'شارع',
            zoneId: 'zone-1',
            scheduledTime: local,
          ));
      expect(body['p_scheduled_time'], '2026-11-03T07:00:00.000Z');
      expect(body.containsKey('p_order_type'), isFalse, reason: 'delivery is the default');
    });

    for (final code in ['store_closed', 'invalid_schedule', 'pickup_unavailable', 'scheduling_unavailable', 'invalid_order_type']) {
      test('$code becomes OrderRejectedException', () async {
        final repo = _repo((request) async => http.Response(
              jsonEncode({'code': 'P0001', 'details': null, 'hint': null, 'message': code}),
              400,
              headers: {'content-type': 'application/json'},
              request: request,
            ));
        await expectLater(_place(repo), throwsA(isA<OrderRejectedException>().having((e) => e.code, 'code', code)));
      });
    }
  });
}
