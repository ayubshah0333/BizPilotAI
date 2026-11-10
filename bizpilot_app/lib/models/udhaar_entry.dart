class UdhaarEntry {
  final int? id;
  final int customerId;
  final String? customerName;
  final String type; // 'credit' (customer took items on credit) or 'payment' (customer paid back money)
  final double amount;
  final String notes;
  final DateTime createdAt;

  const UdhaarEntry({
    this.id,
    required this.customerId,
    this.customerName,
    required this.type,
    required this.amount,
    this.notes = '',
    required this.createdAt,
  });

  bool get isPayment => type.toLowerCase() == 'payment';
  bool get isCredit => type.toLowerCase() == 'credit';

  factory UdhaarEntry.fromJson(Map<String, dynamic> json) {
    final createdAtStr = json['created_at']?.toString() ?? json['createdAt']?.toString();
    final parsedDate = createdAtStr != null
        ? (DateTime.tryParse(createdAtStr) ?? DateTime.now())
        : DateTime.now();

    return UdhaarEntry(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? ''),
      customerId: json['customer_id'] is int
          ? json['customer_id'] as int
          : int.tryParse(json['customer_id']?.toString() ?? json['customerId']?.toString() ?? '0') ?? 0,
      customerName: json['customer_name']?.toString() ?? json['customerName']?.toString(),
      type: json['type']?.toString().toLowerCase() ?? 'credit',
      amount: double.tryParse(json['amount']?.toString() ?? '0.0') ?? 0.0,
      notes: json['notes']?.toString() ?? '',
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'customer_id': customerId,
      if (customerName != null) 'customer_name': customerName,
      'type': type,
      'amount': amount,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toSqlMap() {
    return {
      if (id != null) 'id': id,
      'customer_id': customerId,
      'customer_name': customerName ?? '',
      'type': type,
      'amount': amount,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
