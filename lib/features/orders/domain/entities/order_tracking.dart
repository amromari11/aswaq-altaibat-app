import 'order_ref.dart';
import 'order_status.dart';

class OrderLine {
  const OrderLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.unit,
  });

  final String name;
  final String? unit;
  final int quantity;
  final double unitPrice;
  final double lineTotal;

  factory OrderLine.fromJson(Map<String, dynamic> json) => OrderLine(
        name: (json['name_ar'] ?? json['name'] ?? '') as String,
        unit: json['unit'] as String?,
        quantity: (json['quantity'] as num).toInt(),
        unitPrice: (json['unit_price'] as num).toDouble(),
        lineTotal: (json['line_total'] as num).toDouble(),
      );
}

/// The driver's last reported position (backend supabase/010). Only present
/// while the order is out for delivery.
class DriverLocation {
  const DriverLocation({required this.latitude, required this.longitude, required this.updatedAt});

  final double latitude;
  final double longitude;
  final DateTime updatedAt;

  factory DriverLocation.fromJson(Map<String, dynamic> json) => DriverLocation(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      );

  @override
  bool operator ==(Object other) =>
      other is DriverLocation && other.latitude == latitude && other.longitude == longitude && other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(latitude, longitude, updatedAt);
}

/// One order as `get_order_tracking` returns it.
class OrderTracking {
  const OrderTracking({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.deliveryAddress,
    required this.items,
    this.zoneName,
    this.etaMinutes,
    this.notes,
    this.customerName,
    this.paymentMethod = 'cash',
    this.deliveryLat,
    this.deliveryLng,
    this.driver,
  });

  final String id;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final String deliveryAddress;
  final List<OrderLine> items;
  final String? zoneName;
  final int? etaMinutes;
  final String? notes;
  final String? customerName;
  final String paymentMethod;

  /// The pin the customer dropped on the map at checkout; null when they only
  /// typed an address.
  final double? deliveryLat;
  final double? deliveryLng;

  /// Where the driver is right now. Null unless the order is out for delivery
  /// *and* the driver has reported a position.
  final DriverLocation? driver;

  bool get hasDeliveryPin => deliveryLat != null && deliveryLng != null;

  /// This order with the driver moved (or [location] cleared with null).
  OrderTracking withDriver(DriverLocation? location) => OrderTracking(
        id: id,
        status: status,
        createdAt: createdAt,
        updatedAt: updatedAt,
        subtotal: subtotal,
        deliveryFee: deliveryFee,
        total: total,
        deliveryAddress: deliveryAddress,
        items: items,
        zoneName: zoneName,
        etaMinutes: etaMinutes,
        notes: notes,
        customerName: customerName,
        paymentMethod: paymentMethod,
        deliveryLat: deliveryLat,
        deliveryLng: deliveryLng,
        driver: location,
      );

  /// When the order is expected to arrive: placed-at plus the zone's ETA.
  DateTime? get expectedBy =>
      etaMinutes == null ? null : createdAt.add(Duration(minutes: etaMinutes!));

  factory OrderTracking.fromJson(Map<String, dynamic> json) => OrderTracking(
        id: json['id'] as String,
        status: OrderStatus.fromString(json['status'] as String?),
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
        subtotal: (json['subtotal'] as num).toDouble(),
        deliveryFee: (json['delivery_fee'] as num).toDouble(),
        total: (json['total_price'] as num).toDouble(),
        deliveryAddress: (json['delivery_address'] as String?) ?? '',
        zoneName: json['zone_name_ar'] as String?,
        etaMinutes: (json['eta_minutes'] as num?)?.toInt(),
        notes: json['notes'] as String?,
        customerName: json['customer_name'] as String?,
        paymentMethod: (json['payment_method'] as String?) ?? 'cash',
        deliveryLat: (json['delivery_lat'] as num?)?.toDouble(),
        deliveryLng: (json['delivery_lng'] as num?)?.toDouble(),
        driver: json['driver'] == null
            ? null
            : DriverLocation.fromJson(Map<String, dynamic>.from(json['driver'] as Map)),
        items: [
          for (final line in (json['items'] as List? ?? const []))
            OrderLine.fromJson(line as Map<String, dynamic>),
        ],
      );
}

/// One row of the orders list (`list_orders_summary`).
class OrderSummary {
  const OrderSummary({
    required this.ref,
    required this.status,
    required this.createdAt,
    required this.total,
    required this.itemCount,
    this.zoneName,
  });

  final OrderRef ref;
  final OrderStatus status;
  final DateTime createdAt;
  final double total;
  final int itemCount;
  final String? zoneName;
}
