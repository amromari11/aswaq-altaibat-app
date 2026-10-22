class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.zoneId,
    required this.details,
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  final String id;

  /// Short user-facing name, e.g. "المنزل" or "العمل".
  final String label;
  final String zoneId;

  /// Street / building / landmark text typed by the customer.
  final String details;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  bool get hasPin => latitude != null && longitude != null;

  SavedAddress copyWith({
    String? label,
    String? zoneId,
    String? details,
    double? latitude,
    double? longitude,
    bool? isDefault,
  }) {
    return SavedAddress(
      id: id,
      label: label ?? this.label,
      zoneId: zoneId ?? this.zoneId,
      details: details ?? this.details,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
