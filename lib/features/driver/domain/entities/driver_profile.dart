/// The signed-in user's role and, for drivers, their availability
/// (`profiles.role` / `profiles.is_available`, backend supabase/019).
class DriverProfile {
  const DriverProfile({required this.role, this.isAvailable = false, this.fullName});

  /// Anyone without the driver columns yet (019 not applied) is a customer.
  static const customer = DriverProfile(role: 'customer');

  final String role;
  final bool isAvailable;
  final String? fullName;

  bool get isDriver => role == 'driver';
}
