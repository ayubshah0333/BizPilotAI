class Customer {
  final int id;
  final String name;
  final String phone;
  final String address;
  final double creditLimit;
  final double currentBalance; // positive means customer owes money (Udhaar)

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.address = '',
    this.creditLimit = 0.0,
    this.currentBalance = 0.0,
  });

  bool get hasOutstandingUdhaar => currentBalance > 0.01;
  bool get isOverLimit => creditLimit > 0 && currentBalance > creditLimit;

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    String? address,
    double? creditLimit,
    double? currentBalance,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      creditLimit: creditLimit ?? this.creditLimit,
      currentBalance: currentBalance ?? this.currentBalance,
    );
  }

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      creditLimit: json['credit_limit'] != null
          ? (double.tryParse(json['credit_limit'].toString()) ?? 0.0)
          : (double.tryParse(json['creditLimit']?.toString() ?? '0.0') ?? 0.0),
      currentBalance: json['current_balance'] != null
          ? (double.tryParse(json['current_balance'].toString()) ?? 0.0)
          : (double.tryParse(json['currentBalance']?.toString() ?? '0.0') ?? 0.0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'credit_limit': creditLimit,
      'current_balance': currentBalance,
    };
  }

  Map<String, dynamic> toSqlMap() {
    return {
      'id': id == 0 ? null : id,
      'name': name,
      'phone': phone,
      'address': address,
      'credit_limit': creditLimit,
      'current_balance': currentBalance,
    };
  }
}
