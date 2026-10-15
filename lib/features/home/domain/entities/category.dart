class Category {
  const Category({
    required this.id,
    required this.name,
    required this.nameAr,
    this.imageUrl,
    this.displayOrder = 0,
  });

  final String id;
  final String name;
  final String nameAr;
  final String? imageUrl;
  final int displayOrder;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      nameAr: (json['name_ar'] as String?) ?? (json['name'] as String?) ?? '',
      imageUrl: json['image_url'] as String?,
      displayOrder: (json['display_order'] as int?) ?? 0,
    );
  }
}
