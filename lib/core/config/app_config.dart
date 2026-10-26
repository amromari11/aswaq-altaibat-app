/// Supabase project configuration.
///
/// The anon key is safe to ship in a client app by design — Supabase expects
/// it to be public, and Row Level Security on the database (not secrecy of
/// this key) is what actually protects data. Never put the `service_role`
/// key here or anywhere in this app; that one stays server-side only (the
/// admin dashboard).
class AppConfig {
  const AppConfig._();

  // Confirmed two independent ways: DNS-resolved and returned real data
  // during the backend work on this project, and the project ref
  // ("fbtxwrxewykgewrykvir") decoded from the anon key's JWT payload below
  // matches exactly. Several different, incorrect variants of this ref have
  // been typed into chat across this project — this is the verified one.
  static const String supabaseUrl = 'https://fbtxwrxewykgewrykvir.supabase.co';

  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZidHh3cnhld3lrZ2V3cnlrdmlyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE0NTkyMzIsImV4cCI6MjEwNzAzNTIzMn0.efX1pWoRX9gTR23SrAnptSECGvHzK_TLm7TUNWfBsJ4';

  static const String appName = 'أسواق الطيبات';

  /// Free-delivery threshold, in JOD. Shown in the floating cart bar's
  /// "add X more for free delivery" progress indicator.
  static const double freeDeliveryThresholdJod = 20.0;

  static const double deliveryFeeJod = 1.5;

  /// Where the store is — the "store" marker and the start of the delivery
  /// route on the order-tracking map.
  ///
  /// From the shop's Plus Code `33FW+84 Zarqa` (= `8G4R33FW+84`), decoded to
  /// the centre of its ~14 m cell. Keep `STORE_LAT` / `STORE_LNG` in the admin
  /// dashboard's `utils/store.py` in step with these.
  static const String storeName = 'أسواق الطيبات';
  static const double storeLatitude = 32.073313;
  static const double storeLongitude = 36.095312;
}
