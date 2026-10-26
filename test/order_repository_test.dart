import 'dart:convert';

import 'package:aswaq_altaibat/features/orders/data/repositories/order_tracking_repository.dart';
import 'package:aswaq_altaibat/features/orders/domain/entities/order_ref.dart';
import 'package:aswaq_altaibat/features/orders/domain/entities/order_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _a = OrderRef(id: '3f9a1c00-1111-4111-8111-aaaaaaaaaaaa', token: 'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa');
const _b = OrderRef(id: '7b2e4d00-2222-4222-8222-bbbbbbbbbbbb', token: 'bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb');

OrderTrackingRepository _repo(Future<http.Response> Function(http.Request request) handler) {
  return OrderTrackingRepository(SupabaseClient(
    'http://localhost:54321',
    'test-anon-key',
    httpClient: MockClient(handler),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  ));
}

http.Response _json(Object? body, http.Request request, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'}, request: request);

void main() {
  test('fetchTracking sends the id and token, and parses the order', () async {
    late http.Request seen;
    final repo = _repo((request) async {
      seen = request;
      return _json({
        'id': _a.id, 'status': 'out_for_delivery', 'created_at': '2026-10-27T09:00:00+00:00',
        'updated_at': '2026-10-27T09:20:00+00:00', 'subtotal': 8.25, 'delivery_fee': 1.5, 'total_price': 9.75,
        'delivery_address': 'x', 'zone_name_ar': 'الغويرية', 'eta_minutes': 25, 'items': [],
      }, request);
    });

    final order = await repo.fetchTracking(_a);

    expect(seen.url.path, '/rest/v1/rpc/get_order_tracking');
    expect(jsonDecode(seen.body), {'p_order_id': _a.id, 'p_token': _a.token});
    expect(order!.status, OrderStatus.outForDelivery);
    expect(order.etaMinutes, 25);
  });

  test('fetchTracking returns null when the database finds no matching order', () async {
    final repo = _repo((request) async => _json(null, request));
    expect(await repo.fetchTracking(_a), isNull);
  });

  test('fetchTracking surfaces server errors (the screen shows retry)', () async {
    final repo = _repo((request) async => _json({'code': '500', 'message': 'boom'}, request, 500));
    await expectLater(repo.fetchTracking(_a), throwsA(isA<PostgrestException>()));
  });

  test('listSummaries sends id + token refs and re-attaches each order\'s own token', () async {
    late http.Request seen;
    final repo = _repo((request) async {
      seen = request;
      return _json([
        {'id': _b.id, 'status': 'delivered', 'created_at': '2026-10-26T09:00:00+00:00', 'updated_at': '2026-10-26T10:00:00+00:00',
         'subtotal': 5, 'delivery_fee': 1, 'total_price': 6, 'item_count': 2, 'zone_name_ar': 'وسط الزرقاء', 'eta_minutes': 25},
        {'id': _a.id, 'status': 'preparing', 'created_at': '2026-10-27T09:00:00+00:00', 'updated_at': '2026-10-27T09:05:00+00:00',
         'subtotal': 8.25, 'delivery_fee': 1.5, 'total_price': 9.75, 'item_count': 3, 'zone_name_ar': null, 'eta_minutes': null},
      ], request);
    });

    final summaries = await repo.listSummaries([_a, _b]);

    expect(seen.url.path, '/rest/v1/rpc/list_orders_summary');
    expect(jsonDecode(seen.body), {
      'p_refs': [
        {'id': _a.id, 'token': _a.token},
        {'id': _b.id, 'token': _b.token},
      ],
    });
    expect(summaries.map((s) => s.ref), [_b, _a], reason: 'each row keeps the token of its own order');
    expect(summaries.first.status, OrderStatus.delivered);
    expect(summaries.last.itemCount, 3);
    expect(summaries.last.zoneName, isNull);
  });

  test('listSummaries with nothing to look up does not call the server', () async {
    var called = false;
    final repo = _repo((request) async {
      called = true;
      return _json([], request);
    });
    expect(await repo.listSummaries(const []), isEmpty);
    expect(called, isFalse);
  });

  test('listSummaries asks about at most 50 orders', () async {
    late http.Request seen;
    final repo = _repo((request) async {
      seen = request;
      return _json([], request);
    });
    await repo.listSummaries([for (var i = 0; i < 80; i++) OrderRef(id: 'id-$i', token: 't-$i')]);
    expect((jsonDecode(seen.body)['p_refs'] as List), hasLength(50));
  });

  test('fetchAccountOrderRefs reads the signed-in customer\'s own orders (id + tracking token)', () async {
    late http.Request seen;
    final repo = _repo((request) async {
      seen = request;
      return _json([
        {'id': _a.id, 'tracking_token': _a.token},
        {'id': _b.id, 'tracking_token': _b.token},
      ], request);
    });

    expect(await repo.fetchAccountOrderRefs(), [_a, _b]);
    expect(seen.url.path, '/rest/v1/orders');
    expect(seen.url.queryParameters['select'], 'id,tracking_token');
    expect(seen.url.queryParameters['order'], startsWith('created_at.desc'));
    expect(seen.url.queryParameters['limit'], '50');
  });
}
