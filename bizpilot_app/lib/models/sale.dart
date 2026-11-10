import 'sale_item.dart';

class Sale {
  final int? id;
  final String invoiceNumber;
  final int? customerId;
  final String customerName;
  final double totalAmount;
  final double discountAmount;
  final double taxAmount;
  final double netAmount;
  final String paymentMethod; // 'Cash', 'Udhaar', 'Card'
  final List<SaleItem> items;
  final DateTime createdAt;
  final bool isSynced;

  const Sale({
    this.id,
    required this.invoiceNumber,
    this.customerId,
    required this.customerName,
    required this.totalAmount,
    this.discountAmount = 0.0,
    this.taxAmount = 0.0,
    required this.netAmount,
    required this.paymentMethod,
    required this.items,
    required this.createdAt,
    this.isSynced = true,
  });

  double get calculatedTotalProfit {
    double sum = 0.0;
    for (final it in items) {
      sum += it.profit;
    }
    return sum - discountAmount;
  }

  factory Sale.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'];
    List<SaleItem> parsedItems = [];
    if (rawItems is List) {
      parsedItems = rawItems
          .map((i) => SaleItem.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList();
    }

    final createdAtStr = json['created_at']?.toString() ?? json['createdAt']?.toString();
    final parsedDate = createdAtStr != null
        ? (DateTime.tryParse(createdAtStr) ?? DateTime.now())
        : DateTime.now();

    return Sale(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? ''),
      invoiceNumber: json['invoice_number']?.toString() ?? json['invoiceNumber']?.toString() ?? '',
      customerId: json['customer_id'] is int
          ? json['customer_id'] as int
          : int.tryParse(json['customer_id']?.toString() ?? json['customerId']?.toString() ?? ''),
      customerName: json['customer_name']?.toString() ?? json['customerName']?.toString() ?? 'Walk-in Customer',
      totalAmount: (double.tryParse(json['total_amount']?.toString() ?? json['totalAmount']?.toString() ?? '0.0') ?? 0.0),
      discountAmount: (double.tryParse(json['discount_amount']?.toString() ?? json['discountAmount']?.toString() ?? '0.0') ?? 0.0),
      taxAmount: (double.tryParse(json['tax_amount']?.toString() ?? json['taxAmount']?.toString() ?? '0.0') ?? 0.0),
      netAmount: (double.tryParse(json['net_amount']?.toString() ?? json['netAmount']?.toString() ?? '0.0') ?? 0.0),
      paymentMethod: json['payment_method']?.toString() ?? json['paymentMethod']?.toString() ?? 'Cash',
      items: parsedItems,
      createdAt: parsedDate,
      isSynced: json['is_synced'] == 1 || json['is_synced'] == true || json['isSynced'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'invoice_number': invoiceNumber,
      'customer_id': customerId,
      'customer_name': customerName,
      'total_amount': totalAmount,
      'discount_amount': discountAmount,
      'tax_amount': taxAmount,
      'net_amount': netAmount,
      'payment_method': paymentMethod,
      'created_at': createdAt.toIso8601String(),
      'items': items.map((i) => i.toJson()).toList(),
    };
  }

  Map<String, dynamic> toSqlMap() {
    return {
      if (id != null) 'id': id,
      'invoice_number': invoiceNumber,
      'customer_id': customerId,
      'customer_name': customerName,
      'total_amount': totalAmount,
      'discount_amount': discountAmount,
      'tax_amount': taxAmount,
      'net_amount': netAmount,
      'payment_method': paymentMethod,
      'created_at': createdAt.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }
}
