class Category {
  final int id;
  final String name;
  final String icon;

  const Category({
    required this.id,
    required this.name,
    this.icon = 'category',
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'category',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
    };
  }
}
