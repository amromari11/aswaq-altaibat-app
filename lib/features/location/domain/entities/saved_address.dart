class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.zoneId,
    required this.details,
    this.latitude,
    this.longitude,
    this.isDefault = false,
    this.isPersisted = false,
  });

  final String id;

  /// Short user-facing name, e.g. "المنزل" or "العمل".
  final String label;
  final String zoneId;

  /// Street / building / landmark text typed by the customer
  /// (`user_addresses.address_line`).
  final String details;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  /// True once this row exists in `user_addresses` — [id] is then the real
  /// server uuid and safe to send as `orders.address_id`. Guest addresses
  /// stay local-only with a client-generated id.
  final bool isPersisted;

  bool get hasPin => latitude != null && longitude != null;

  factory SavedAddress.fromJson(Map<String, dynamic> json) {
    return SavedAddress(
      id: json['id'] as String,
      label: json['label'] as String,
      zoneId: json['zone_id'] as String,
      details: json['address_line'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isDefault: json['is_default'] as bool? ?? false,
      isPersisted: true,
    );
  }

  /// Columns written to `user_addresses` (everything but id/user_id).
  Map<String, dynamic> toRow() => {
        'label': label,
        'zone_id': zoneId,
        'address_line': details,
        'latitude': latitude,
        'longitude': longitude,
        'is_default': isDefault,
      };

  SavedAddress copyWith({
    String? id,
    String? label,
    String? zoneId,
    String? details,
    double? latitude,
    double? longitude,
    bool? isDefault,
    bool? isPersisted,
  }) {
    return SavedAddress(
      id: id ?? this.id,
      label: label ?? this.label,
      zoneId: zoneId ?? this.zoneId,
      details: details ?? this.details,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDefault: isDefault ?? this.isDefault,
      isPersisted: isPersisted ?? this.isPersisted,
    );
  }
}
