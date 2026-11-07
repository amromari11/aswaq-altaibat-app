import '../../../orders/domain/entities/order_status.dart';

/// One order assigned to the signed-in driver, as returned by the
/// `driver_assigned_orders` database function (backend supabase/019).
class DriverOrder {
  const DriverOrder({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.deliveryAddress,
    required this.subtotal,
    required this.deliveryFee,
    required this.discount,
    required this.total,
    required this.paymentMethod,
    this.scheduledTime,
    this.pickedUpAt,
    this.customerName,
    this.customerPhone,
    this.deliveryLat,
    this.deliveryLng,
    this.zoneName,
    this.notes,
    this.pointsRedeemed = 0,
    this.itemCount = 0,
  });

  final String id;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime? scheduledTime;
  final DateTime? pickedUpAt;
  final String? customerName;

  /// E.164 (+962791112233) — the snapshot taken when the order was placed.
  final String? customerPhone;
  final String deliveryAddress;
  final double? deliveryLat;
  final double? deliveryLng;
  final String? zoneName;
  final String? notes;
  final double subtotal;
  final double deliveryFee;
  final double discount;
  final double total;

  /// 'cash' or 'card' (orders.payment_method).
  final String paymentMethod;

  /// Loyalty points the customer spent on this order.
  final int pointsRedeemed;
  final int itemCount;

  factory DriverOrder.fromJson(Map<String, dynamic> json) {
    double? toDouble(Object? v) => v == null ? null : (v as num).toDouble();
    DateTime? toTime(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();
    return DriverOrder(
      id: json['id'] as String,
      status: OrderStatus.fromString(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      scheduledTime: toTime(json['scheduled_time']),
      pickedUpAt: toTime(json['picked_up_at']),
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      deliveryAddress: (json['delivery_address'] as String?) ?? '',
      deliveryLat: toDouble(json['delivery_lat']),
      deliveryLng: toDouble(json['delivery_lng']),
      zoneName: json['zone_name_ar'] as String?,
      notes: json['notes'] as String?,
      subtotal: toDouble(json['subtotal']) ?? 0,
      deliveryFee: toDouble(json['delivery_fee']) ?? 0,
      discount: toDouble(json['discount_amount']) ?? 0,
      total: toDouble(json['total_price']) ?? 0,
      paymentMethod: (json['payment_method'] as String?) ?? 'cash',
      pointsRedeemed: (json['loyalty_points_redeemed'] as num?)?.toInt() ?? 0,
      itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Same short code the customer sees on their tracking screen.
  String get code => '#${id.replaceAll('-', '').substring(0, 6).toUpperCase()}';

  bool get isPickedUp => status == OrderStatus.outForDelivery;

  bool get isCash => paymentMethod == 'cash';

  /// "نقداً عند الاستلام", "بطاقة", or "نقاط" when points covered everything.
  String get paymentMethodAr {
    if (pointsRedeemed > 0 && total <= 0) return 'نقاط';
    return switch (paymentMethod) {
      'cash' => 'نقداً عند الاستلام',
      'card' => 'بطاقة',
      _ => paymentMethod,
    };
  }

  /// The method with the points the customer used, if any, on one line.
  String get paymentLabelAr {
    if (pointsRedeemed <= 0) return paymentMethodAr;
    if (total <= 0) return 'نقاط ($pointsRedeemed نقطة)';
    return '$paymentMethodAr + نقاط ($pointsRedeemed نقطة)';
  }

  /// Google Maps search for the drop-off: the pinned location when there is
  /// one, otherwise the typed address (with the city, so it resolves locally).
  Uri get mapsUri => Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': (deliveryLat != null && deliveryLng != null)
            ? '$deliveryLat,$deliveryLng'
            : '$deliveryAddress، الزرقاء',
      });

  Uri? get callUri => (customerPhone == null || customerPhone!.trim().isEmpty)
      ? null
      : Uri(scheme: 'tel', path: customerPhone!.trim());
}

/// What `driver_mark_delivered` reports back.
class DeliveryResult {
  const DeliveryResult({required this.pointsAwarded, required this.available, this.alreadyDelivered = false});

  final int pointsAwarded;

  /// The driver's availability after the delivery (switched back on when this
  /// was the last order and a pick-up had switched it off).
  final bool available;
  final bool alreadyDelivered;

  factory DeliveryResult.fromJson(Map<String, dynamic> json) => DeliveryResult(
        pointsAwarded: (json['points_awarded'] as num?)?.toInt() ?? 0,
        available: json['available'] as bool? ?? false,
        alreadyDelivered: json['already_delivered'] as bool? ?? false,
      );
}
