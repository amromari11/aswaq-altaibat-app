/// How the customer gets the order (orders.order_type, backend migration 015).
enum OrderType {
  delivery,
  pickup;

  /// The value `place_order` and the orders table use.
  String get wire => name;

  static OrderType fromWire(String? value) =>
      value == 'pickup' ? OrderType.pickup : OrderType.delivery;
}

/// The pickup branch and the time-slot rules (`store_settings`, one row).
/// `place_order` enforces the same values, so what the app offers is what the
/// database accepts.
class StoreSettings {
  const StoreSettings({
    required this.branchName,
    required this.branchAddress,
    required this.latitude,
    required this.longitude,
    required this.opensAtMinutes,
    required this.closesAtMinutes,
    this.branchPhone,
    this.pickupEnabled = true,
    this.schedulingEnabled = true,
    this.slotMinutes = 60,
    this.minLeadMinutes = 60,
    this.maxDaysAhead = 2,
    this.pickupReadyMinutes = 20,
  });

  final String branchName;
  final String branchAddress;
  final String? branchPhone;
  final double latitude;
  final double longitude;

  /// Minutes after midnight, Amman time. 1440 = closes at midnight.
  final int opensAtMinutes;
  final int closesAtMinutes;
  final bool pickupEnabled;
  final bool schedulingEnabled;
  final int slotMinutes;
  final int minLeadMinutes;
  final int maxDaysAhead;
  final int pickupReadyMinutes;

  /// '08:00 – 23:00'.
  String get hoursLabel => '${clock(opensAtMinutes)} – ${clock(closesAtMinutes)}';

  static String clock(int minutes) {
    if (minutes >= 1440) return '24:00';
    final m = minutes;
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }

  /// 'HH:MM[:SS]' -> minutes after midnight ('24:00:00' -> 1440).
  static int parseClock(String value) {
    final parts = value.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  factory StoreSettings.fromJson(Map<String, dynamic> json) => StoreSettings(
        branchName: json['branch_name_ar'] as String,
        branchAddress: json['branch_address_ar'] as String,
        branchPhone: json['branch_phone'] as String?,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        opensAtMinutes: parseClock(json['opens_at'] as String),
        closesAtMinutes: parseClock(json['closes_at'] as String),
        pickupEnabled: json['pickup_enabled'] as bool? ?? true,
        schedulingEnabled: json['scheduling_enabled'] as bool? ?? true,
        slotMinutes: (json['slot_minutes'] as num?)?.toInt() ?? 60,
        minLeadMinutes: (json['min_lead_minutes'] as num?)?.toInt() ?? 60,
        maxDaysAhead: (json['max_days_ahead'] as num?)?.toInt() ?? 2,
        pickupReadyMinutes: (json['pickup_ready_minutes'] as num?)?.toInt() ?? 20,
      );
}

/// A delivery/pickup window. [start] and [end] are real instants (UTC).
class TimeSlot {
  const TimeSlot({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  @override
  bool operator ==(Object other) => other is TimeSlot && other.start.isAtSameMomentAs(start);

  @override
  int get hashCode => start.toUtc().millisecondsSinceEpoch.hashCode;
}

/// The slots of one day, for the day chips.
class SlotDay {
  const SlotDay({required this.label, required this.slots});

  final String label;
  final List<TimeSlot> slots;
}
