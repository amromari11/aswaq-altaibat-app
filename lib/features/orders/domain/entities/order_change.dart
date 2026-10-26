import 'order_tracking.dart';

/// What a live order channel tells the app (see backend supabase/009 and 010).
sealed class OrderChange {
  const OrderChange();
}

/// Something about the order changed (a status broadcast), or the channel
/// (re)connected so a change may have been missed: fetch it again.
class OrderRefreshNeeded extends OrderChange {
  const OrderRefreshNeeded();
}

/// The driver moved. Carries the new position, so the map can update without
/// another round trip.
class DriverMoved extends OrderChange {
  const DriverMoved(this.location);

  final DriverLocation location;
}
