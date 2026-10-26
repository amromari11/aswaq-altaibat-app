import 'dart:math';

/// What a device needs to look an order up without an account: its id plus the
/// secret tracking token the phone made up when placing it. Whoever holds both
/// can track that order (see backend supabase/009).
class OrderRef {
  const OrderRef({required this.id, required this.token});

  final String id;
  final String token;

  factory OrderRef.fromJson(Map<String, dynamic> json) =>
      OrderRef(id: json['id'] as String, token: json['token'] as String);

  Map<String, dynamic> toJson() => {'id': id, 'token': token};

  @override
  bool operator ==(Object other) => other is OrderRef && other.id == id && other.token == token;

  @override
  int get hashCode => Object.hash(id, token);

  /// Short human code, e.g. `#3F9A1C`.
  String get code => '#${id.replaceAll('-', '').substring(0, 6).toUpperCase()}';

  /// [code] for display inside right-to-left Arabic text. Without the
  /// left-to-right isolate (U+2066 ... U+2069) the `#` lands after the digits
  /// ("3F9A1C#"), because a leading `#` has no direction of its own.
  String get displayCode => '\u2066$code\u2069';
}

/// A random (version 4) UUID from the platform's secure generator — the order's
/// tracking token. 122 random bits, so it can't be guessed.
String newTrackingToken([Random? random]) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
  String hex(int from, int to) =>
      bytes.sublist(from, to).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
