class SaleItem {
  final int? id;
  final int? saleId;
  final int productId;
  final String productName;
  final double unitPrice;
  final double costPrice;
  final int quantity;
  final double subtotal;

  const SaleItem({
    this.id,
    this.saleId,
    required this.productId,
    required this.productName,
    required this.unitPrice,
    this.costPrice = 0.0,
    required this.quantity,
    required this.subtotal,
  });

  double get profit => (unitPrice - costPrice) * quantity;

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    final qty = json['quantity'] != null
        ? (int.tryParse(json['quantity'].toString()) ?? 1)
        : 1;
    final price = json['unit_price'] != null
        ? (double.tryParse(json['unit_price'].toString()) ?? 0.0)
        : (double.tryParse(json['unitPrice']?.toString() ?? '0.0') ?? 0.0);
    final cost = json['cost_price'] != null
        ? (double.tryParse(json['cost_price'].toString()) ?? 0.0)
        : (double.tryParse(json['costPrice']?.toString() ?? '0.0') ?? 0.0);

    return SaleItem(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? ''),
      saleId: json['sale_id'] is int ? json['sale_id'] as int : int.tryParse(json['saleId']?.toString() ?? ''),
      productId: json['product_id'] is int
          ? json['product_id'] as int
          : int.tryParse(json['product_id']?.toString() ?? json['productId']?.toString() ?? '0') ?? 0,
      productName: json['product_name']?.toString() ?? json['productName']?.toString() ?? '',
      unitPrice: price,
      costPrice: cost,
      quantity: qty,
      subtotal: json['subtotal'] != null
          ? (double.tryParse(json['subtotal'].toString()) ?? (price * qty))
          : (price * qty),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (saleId != null) 'sale_id': saleId,
      'product_id': productId,
      'product_name': productName,
      'unit_price': unitPrice,
      'cost_price': costPrice,
      'quantity': quantity,
      'subtotal': subtotal,
    };
  }
}
