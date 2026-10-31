import '../../../cart/domain/entities/fulfillment.dart';

/// Mirrors the `order_status` enum in the database.
///
/// Pickup orders (backend 015) reuse the same statuses: "out for delivery"
/// reads as "ready for pickup" and "delivered" as "picked up" — use the
/// `…For(type)` methods wherever an order's type is known.
enum OrderStatus {
  pending,
  confirmed,
  preparing,
  outForDelivery,
  delivered,
  cancelled;

  static OrderStatus fromString(String? value) {
    switch (value) {
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'preparing':
        return OrderStatus.preparing;
      case 'out_for_delivery':
        return OrderStatus.outForDelivery;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'pending':
      default:
        return OrderStatus.pending;
    }
  }

  /// Position on the 4-step timeline (تم الاستلام → قيد التحضير → خرج للتوصيل →
  /// تم التسليم). The store's "confirmed" is still the first step: the order
  /// has been received and acknowledged, but preparation hasn't started.
  /// `cancelled` is off the timeline.
  int get step {
    switch (this) {
      case OrderStatus.pending:
      case OrderStatus.confirmed:
      case OrderStatus.cancelled:
        return 0;
      case OrderStatus.preparing:
        return 1;
      case OrderStatus.outForDelivery:
        return 2;
      case OrderStatus.delivered:
        return 3;
    }
  }

  /// Still on its way to the customer (shown under "active orders").
  bool get isActive => this != OrderStatus.delivered && this != OrderStatus.cancelled;

  String get labelAr {
    switch (this) {
      case OrderStatus.pending:
        return 'تم الاستلام';
      case OrderStatus.confirmed:
        return 'تم التأكيد';
      case OrderStatus.preparing:
        return 'قيد التحضير';
      case OrderStatus.outForDelivery:
        return 'خرج للتوصيل';
      case OrderStatus.delivered:
        return 'تم التسليم';
      case OrderStatus.cancelled:
        return 'ملغي';
    }
  }

  String labelFor(OrderType type) {
    if (type == OrderType.pickup) {
      if (this == OrderStatus.outForDelivery) return 'جاهز للاستلام';
      if (this == OrderStatus.delivered) return 'تم الاستلام';
    }
    return labelAr;
  }

  String headlineFor(OrderType type) {
    if (type == OrderType.pickup) {
      if (this == OrderStatus.outForDelivery) return 'طلبك جاهز للاستلام';
      if (this == OrderStatus.delivered) return 'تم استلام طلبك';
    }
    return headlineAr;
  }

  String detailFor(OrderType type) {
    if (type == OrderType.pickup) {
      if (this == OrderStatus.outForDelivery) {
        return 'تفضّل إلى الفرع لاستلام طلبك — الدفع عند الاستلام.';
      }
      if (this == OrderStatus.preparing) return 'نجهّز منتجاتك الآن، وسنخبرك عندما يصبح جاهزاً.';
    }
    return detailAr;
  }

  /// One-line headline for the tracking screen.
  String get headlineAr {
    switch (this) {
      case OrderStatus.pending:
        return 'تم استلام طلبك';
      case OrderStatus.confirmed:
        return 'تم تأكيد طلبك';
      case OrderStatus.preparing:
        return 'جارٍ تحضير طلبك';
      case OrderStatus.outForDelivery:
        return 'طلبك في الطريق إليك';
      case OrderStatus.delivered:
        return 'تم تسليم طلبك';
      case OrderStatus.cancelled:
        return 'تم إلغاء الطلب';
    }
  }

  String get detailAr {
    switch (this) {
      case OrderStatus.pending:
        return 'بانتظار تأكيد المتجر لطلبك.';
      case OrderStatus.confirmed:
        return 'أكّد المتجر طلبك وسيبدأ تحضيره قريباً.';
      case OrderStatus.preparing:
        return 'نجهّز منتجاتك الآن.';
      case OrderStatus.outForDelivery:
        return 'السائق في طريقه إليك — يرجى إبقاء هاتفك قريباً.';
      case OrderStatus.delivered:
        return 'بالهناء والعافية! شكراً لتسوقك من أسواق الطيبات.';
      case OrderStatus.cancelled:
        return 'للاستفسار، تواصل مع المتجر.';
    }
  }
}
