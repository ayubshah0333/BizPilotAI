class Product {
  final int id;
  final String name;
  final String sku;
  final String barcode;
  final double costPrice;
  final double sellingPrice;
  final int stockQuantity;
  final int lowStockThreshold;
  final String categoryName;

  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.barcode,
    required this.costPrice,
    required this.sellingPrice,
    required this.stockQuantity,
    this.lowStockThreshold = 5,
    this.categoryName = 'General',
  });

  bool get isOutOfStock => stockQuantity <= 0;
  bool get isLowStock => stockQuantity > 0 && stockQuantity <= lowStockThreshold;
  double get profitMargin => sellingPrice > 0 ? ((sellingPrice - costPrice) / sellingPrice) * 100 : 0.0;
  double get unitProfit => sellingPrice - costPrice;

  Product copyWith({
    int? id,
    String? name,
    String? sku,
    String? barcode,
    double? costPrice,
    double? sellingPrice,
    int? stockQuantity,
    int? lowStockThreshold,
    String? categoryName,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      categoryName: categoryName ?? this.categoryName,
    );
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      barcode: json['barcode']?.toString() ?? '',
      costPrice: json['cost_price'] != null
          ? (double.tryParse(json['cost_price'].toString()) ?? 0.0)
          : (double.tryParse(json['costPrice']?.toString() ?? '0.0') ?? 0.0),
      sellingPrice: json['selling_price'] != null
          ? (double.tryParse(json['selling_price'].toString()) ?? 0.0)
          : (double.tryParse(json['sellingPrice']?.toString() ?? '0.0') ?? 0.0),
      stockQuantity: json['stock_quantity'] != null
          ? (int.tryParse(json['stock_quantity'].toString()) ?? 0)
          : (int.tryParse(json['stockQuantity']?.toString() ?? '0') ?? 0),
      lowStockThreshold: json['low_stock_threshold'] != null
          ? (int.tryParse(json['low_stock_threshold'].toString()) ?? 5)
          : (int.tryParse(json['lowStockThreshold']?.toString() ?? '5') ?? 5),
      categoryName: json['category_name']?.toString() ?? json['categoryName']?.toString() ?? 'General',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sku': sku,
      'barcode': barcode,
      'cost_price': costPrice,
      'selling_price': sellingPrice,
      'stock_quantity': stockQuantity,
      'low_stock_threshold': lowStockThreshold,
      'category_name': categoryName,
    };
  }

  Map<String, dynamic> toSqlMap() {
    return {
      'id': id == 0 ? null : id,
      'name': name,
      'sku': sku,
      'barcode': barcode,
      'cost_price': costPrice,
      'selling_price': sellingPrice,
      'stock_quantity': stockQuantity,
      'low_stock_threshold': lowStockThreshold,
      'category_name': categoryName,
    };
  }
}
