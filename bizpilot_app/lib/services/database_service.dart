import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/product.dart';
import '../models/customer.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../models/udhaar_entry.dart';
import '../models/ai_insight.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;
  bool _isInMemoryFallback = false;

  // In-memory fallbacks if running in pure browser environment
  final List<Product> _memProducts = [];
  final List<Customer> _memCustomers = [];
  final List<Sale> _memSales = [];
  final List<UdhaarEntry> _memUdhaar = [];
  final List<AiInsight> _memInsights = [];

  DatabaseService._init();

  Future<Database?> get database async {
    if (_isInMemoryFallback) return null;
    if (_database != null) return _database!;
    _database = await _initDB('bizpilot_offline.db');
    return _database;
  }

  Future<Database?> _initDB(String filePath) async {
    try {
      if (kIsWeb) {
        _isInMemoryFallback = true;
        _seedMemoryFallback();
        return null;
      }

      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, filePath);

      return await openDatabase(
        path,
        version: 1,
        onCreate: _createDB,
      );
    } catch (e) {
      debugPrint('Database initialization fallback to in-memory: $e');
      _isInMemoryFallback = true;
      _seedMemoryFallback();
      return null;
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        sku TEXT,
        barcode TEXT,
        cost_price REAL NOT NULL,
        selling_price REAL NOT NULL,
        stock_quantity INTEGER NOT NULL,
        low_stock_threshold INTEGER NOT NULL DEFAULT 5,
        category_name TEXT NOT NULL DEFAULT 'General'
      )
    ''');

    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        address TEXT,
        credit_limit REAL NOT NULL DEFAULT 0.0,
        current_balance REAL NOT NULL DEFAULT 0.0
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT UNIQUE NOT NULL,
        customer_id INTEGER,
        customer_name TEXT NOT NULL,
        total_amount REAL NOT NULL,
        discount_amount REAL NOT NULL DEFAULT 0.0,
        tax_amount REAL NOT NULL DEFAULT 0.0,
        net_amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        unit_price REAL NOT NULL,
        cost_price REAL NOT NULL DEFAULT 0.0,
        quantity INTEGER NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE udhaar_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        customer_name TEXT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ai_insights (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        description TEXT NOT NULL,
        urdu_translation TEXT NOT NULL,
        severity TEXT NOT NULL DEFAULT 'info',
        metric_value REAL,
        metric_label TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Populate initial rich demo seed data
    await _seedInitialSqlData(db);
  }

  Future<void> _seedInitialSqlData(Database db) async {
    final products = [
      {'name': 'Nestlé MilkPak 1L', 'sku': 'MLK-001', 'barcode': '8961014101', 'cost_price': 240.0, 'selling_price': 285.0, 'stock_quantity': 42, 'low_stock_threshold': 10, 'category_name': 'Dairy'},
      {'name': 'Shan Biryani Masala 50g', 'sku': 'SHN-002', 'barcode': '8961014102', 'cost_price': 80.0, 'selling_price': 110.0, 'stock_quantity': 18, 'low_stock_threshold': 5, 'category_name': 'Grocery'},
      {'name': 'Tapal Danedar Tea 450g', 'sku': 'TEA-003', 'barcode': '8961014103', 'cost_price': 520.0, 'selling_price': 630.0, 'stock_quantity': 4, 'low_stock_threshold': 6, 'category_name': 'Beverages'},
      {'name': 'Super Basmati Rice 5kg', 'sku': 'RCE-004', 'barcode': '8961014104', 'cost_price': 1400.0, 'selling_price': 1750.0, 'stock_quantity': 2, 'low_stock_threshold': 5, 'category_name': 'Grocery'},
      {'name': 'Olpers Full Cream Milk 1L', 'sku': 'MLK-005', 'barcode': '8961014105', 'cost_price': 245.0, 'selling_price': 290.0, 'stock_quantity': 25, 'low_stock_threshold': 8, 'category_name': 'Dairy'},
      {'name': 'Dalda Cooking Oil 5L', 'sku': 'OIL-006', 'barcode': '8961014106', 'cost_price': 2550.0, 'selling_price': 2850.0, 'stock_quantity': 0, 'low_stock_threshold': 3, 'category_name': 'Grocery'},
      {'name': 'Dawn Sandwich Bread Large', 'sku': 'BRD-007', 'barcode': '8961014107', 'cost_price': 130.0, 'selling_price': 160.0, 'stock_quantity': 15, 'low_stock_threshold': 4, 'category_name': 'Bakery'},
      {'name': 'Surf Excel Quick Wash 1kg', 'sku': 'DET-008', 'barcode': '8961014108', 'cost_price': 480.0, 'selling_price': 570.0, 'stock_quantity': 12, 'low_stock_threshold': 5, 'category_name': 'Household'},
    ];

    for (final p in products) {
      await db.insert('products', p);
    }

    final customers = [
      {'name': 'Haji Muhammad Tariq', 'phone': '03001234567', 'address': 'Shop 4, Main Bazaar', 'credit_limit': 50000.0, 'current_balance': 14500.0},
      {'name': 'Kamran Traders', 'phone': '03219876543', 'address': 'Plot 12, Commercial Area', 'credit_limit': 100000.0, 'current_balance': 28000.0},
      {'name': 'Dr. Fatima Bibi', 'phone': '03335558822', 'address': 'House 88, Street 4', 'credit_limit': 15000.0, 'current_balance': 3200.0},
      {'name': 'Bilal Ahmed Kiryana', 'phone': '03456677889', 'address': 'Gali No 2, Model Town', 'credit_limit': 30000.0, 'current_balance': 0.0},
    ];

    for (final c in customers) {
      await db.insert('customers', c);
    }

    final now = DateTime.now();
    final sampleSales = [
      {
        'invoice_number': 'INV-2026-0001',
        'customer_id': 1,
        'customer_name': 'Haji Muhammad Tariq',
        'total_amount': 2850.0,
        'discount_amount': 50.0,
        'tax_amount': 0.0,
        'net_amount': 2800.0,
        'payment_method': 'Cash',
        'created_at': now.subtract(const Duration(hours: 3)).toIso8601String(),
        'is_synced': 1,
      },
      {
        'invoice_number': 'INV-2026-0002',
        'customer_id': 2,
        'customer_name': 'Kamran Traders',
        'total_amount': 5700.0,
        'discount_amount': 100.0,
        'tax_amount': 0.0,
        'net_amount': 5600.0,
        'payment_method': 'Udhaar',
        'created_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
        'is_synced': 1,
      },
    ];

    for (final s in sampleSales) {
      final saleId = await db.insert('sales', s);
      await db.insert('sale_items', {
        'sale_id': saleId,
        'product_id': 1,
        'product_name': 'Nestlé MilkPak 1L',
        'unit_price': 285.0,
        'cost_price': 240.0,
        'quantity': 10,
        'subtotal': 2850.0,
      });
    }

    final udhaarHistory = [
      {'customer_id': 1, 'customer_name': 'Haji Muhammad Tariq', 'type': 'credit', 'amount': 20000.0, 'notes': 'Monthly grocery invoice purchase', 'created_at': now.subtract(const Duration(days: 7)).toIso8601String()},
      {'customer_id': 1, 'customer_name': 'Haji Muhammad Tariq', 'type': 'payment', 'amount': 5500.0, 'notes': 'Cash received in shop', 'created_at': now.subtract(const Duration(days: 2)).toIso8601String()},
      {'customer_id': 2, 'customer_name': 'Kamran Traders', 'type': 'credit', 'amount': 28000.0, 'notes': 'Bulk order supplies', 'created_at': now.subtract(const Duration(days: 5)).toIso8601String()},
      {'customer_id': 3, 'customer_name': 'Dr. Fatima Bibi', 'type': 'credit', 'amount': 3200.0, 'notes': 'Weekly family essentials', 'created_at': now.subtract(const Duration(days: 3)).toIso8601String()},
    ];

    for (final u in udhaarHistory) {
      await db.insert('udhaar_entries', u);
    }

    final insights = [
      {
        'id': 'ins-1',
        'title': 'High Margin Dairy Acceleration',
        'type': 'trend',
        'description': 'Dairy items accounted for 42% of this week’s net profits. Keep Nestlé and Olpers stocks consistently replenished.',
        'urdu_translation': 'ڈیری مصنوعات نے اس ہفتے کے خالص منافع کا 42 فیصد حصہ بنایا۔ دودھ کے ذخائر کو بروقت برقرار رکھیں۔',
        'severity': 'positive',
        'metric_value': 42.0,
        'metric_label': 'Profit Share',
        'created_at': now.toIso8601String(),
      },
      {
        'id': 'ins-2',
        'title': 'Stockout Imminent: Dalda & Rice',
        'type': 'alert',
        'description': 'Dalda Oil is completely out of stock and Super Basmati Rice has only 2 bags remaining. Reorder today to prevent lost sales.',
        'urdu_translation': 'ڈالڈا کوکنگ آئل ختم ہوچکا ہے اور باسمتی چاول کے صرف 2 بیگز باقی ہیں۔ فوری آرڈر کریں۔',
        'severity': 'critical',
        'metric_value': 0.0,
        'metric_label': 'Dalda Stock',
        'created_at': now.toIso8601String(),
      },
      {
        'id': 'ins-3',
        'title': 'Udhaar Collection Opportunity',
        'type': 'action_tip',
        'description': 'Kamran Traders & Haji Tariq have Rs 42,500 pending for >5 days. Send WhatsApp reminders today.',
        'urdu_translation': 'کامران ٹریڈرز اور حاجی طارق کے 42,500 روپے 5 دن سے زائد سے واجب الادا ہیں۔ واٹس ایپ یاد دہانی بھیجیں۔',
        'severity': 'warning',
        'metric_value': 42500.0,
        'metric_label': 'Pending Total',
        'created_at': now.toIso8601String(),
      },
    ];

    for (final ins in insights) {
      await db.insert('ai_insights', ins);
    }
  }

  void _seedMemoryFallback() {
    if (_memProducts.isNotEmpty) return;
    final now = DateTime.now();

    _memProducts.addAll([
      const Product(id: 1, name: 'Nestlé MilkPak 1L', sku: 'MLK-001', barcode: '8961014101', costPrice: 240.0, sellingPrice: 285.0, stockQuantity: 42, lowStockThreshold: 10, categoryName: 'Dairy'),
      const Product(id: 2, name: 'Shan Biryani Masala 50g', sku: 'SHN-002', barcode: '8961014102', costPrice: 80.0, sellingPrice: 110.0, stockQuantity: 18, lowStockThreshold: 5, categoryName: 'Grocery'),
      const Product(id: 3, name: 'Tapal Danedar Tea 450g', sku: 'TEA-003', barcode: '8961014103', costPrice: 520.0, sellingPrice: 630.0, stockQuantity: 4, lowStockThreshold: 6, categoryName: 'Beverages'),
      const Product(id: 4, name: 'Super Basmati Rice 5kg', sku: 'RCE-004', barcode: '8961014104', costPrice: 1400.0, sellingPrice: 1750.0, stockQuantity: 2, lowStockThreshold: 5, categoryName: 'Grocery'),
      const Product(id: 5, name: 'Olpers Full Cream Milk 1L', sku: 'MLK-005', barcode: '8961014105', costPrice: 245.0, sellingPrice: 290.0, stockQuantity: 25, lowStockThreshold: 8, categoryName: 'Dairy'),
      const Product(id: 6, name: 'Dalda Cooking Oil 5L', sku: 'OIL-006', barcode: '8961014106', costPrice: 2550.0, sellingPrice: 2850.0, stockQuantity: 0, lowStockThreshold: 3, categoryName: 'Grocery'),
      const Product(id: 7, name: 'Dawn Sandwich Bread Large', sku: 'BRD-007', barcode: '8961014107', costPrice: 130.0, sellingPrice: 160.0, stockQuantity: 15, lowStockThreshold: 4, categoryName: 'Bakery'),
      const Product(id: 8, name: 'Surf Excel Quick Wash 1kg', sku: 'DET-008', barcode: '8961014108', costPrice: 480.0, sellingPrice: 570.0, stockQuantity: 12, lowStockThreshold: 5, categoryName: 'Household'),
    ]);

    _memCustomers.addAll([
      const Customer(id: 1, name: 'Haji Muhammad Tariq', phone: '03001234567', address: 'Shop 4, Main Bazaar', creditLimit: 50000.0, currentBalance: 14500.0),
      const Customer(id: 2, name: 'Kamran Traders', phone: '03219876543', address: 'Plot 12, Commercial Area', creditLimit: 100000.0, currentBalance: 28000.0),
      const Customer(id: 3, name: 'Dr. Fatima Bibi', phone: '03335558822', address: 'House 88, Street 4', creditLimit: 15000.0, currentBalance: 3200.0),
      const Customer(id: 4, name: 'Bilal Ahmed Kiryana', phone: '03456677889', address: 'Gali No 2, Model Town', creditLimit: 30000.0, currentBalance: 0.0),
    ]);

    _memSales.addAll([
      Sale(
        id: 1,
        invoiceNumber: 'INV-2026-0001',
        customerId: 1,
        customerName: 'Haji Muhammad Tariq',
        totalAmount: 2850.0,
        discountAmount: 50.0,
        taxAmount: 0.0,
        netAmount: 2800.0,
        paymentMethod: 'Cash',
        items: const [
          SaleItem(productId: 1, productName: 'Nestlé MilkPak 1L', unitPrice: 285.0, costPrice: 240.0, quantity: 10, subtotal: 2850.0),
        ],
        createdAt: now.subtract(const Duration(hours: 3)),
        isSynced: true,
      ),
      Sale(
        id: 2,
        invoiceNumber: 'INV-2026-0002',
        customerId: 2,
        customerName: 'Kamran Traders',
        totalAmount: 5700.0,
        discountAmount: 100.0,
        taxAmount: 0.0,
        netAmount: 5600.0,
        paymentMethod: 'Udhaar',
        items: const [
          SaleItem(productId: 1, productName: 'Nestlé MilkPak 1L', unitPrice: 285.0, costPrice: 240.0, quantity: 20, subtotal: 5700.0),
        ],
        createdAt: now.subtract(const Duration(hours: 1)),
        isSynced: true,
      ),
    ]);

    _memUdhaar.addAll([
      UdhaarEntry(id: 1, customerId: 1, customerName: 'Haji Muhammad Tariq', type: 'credit', amount: 20000.0, notes: 'Monthly grocery invoice purchase', createdAt: now.subtract(const Duration(days: 7))),
      UdhaarEntry(id: 2, customerId: 1, customerName: 'Haji Muhammad Tariq', type: 'payment', amount: 5500.0, notes: 'Cash received in shop', createdAt: now.subtract(const Duration(days: 2))),
      UdhaarEntry(id: 3, customerId: 2, customerName: 'Kamran Traders', type: 'credit', amount: 28000.0, notes: 'Bulk order supplies', createdAt: now.subtract(const Duration(days: 5))),
      UdhaarEntry(id: 4, customerId: 3, customerName: 'Dr. Fatima Bibi', type: 'credit', amount: 3200.0, notes: 'Weekly family essentials', createdAt: now.subtract(const Duration(days: 3))),
    ]);

    _memInsights.addAll([
      AiInsight(
        id: 'ins-1',
        title: 'High Margin Dairy Acceleration',
        type: 'trend',
        description: 'Dairy items accounted for 42% of this week’s net profits. Keep Nestlé and Olpers stocks consistently replenished.',
        urduTranslation: 'ڈیری مصنوعات نے اس ہفتے کے خالص منافع کا 42 فیصد حصہ بنایا۔ دودھ کے ذخائر کو بروقت برقرار رکھیں۔',
        severity: 'positive',
        metricValue: 42.0,
        metricLabel: 'Profit Share',
        createdAt: now,
      ),
      AiInsight(
        id: 'ins-2',
        title: 'Stockout Imminent: Dalda & Rice',
        type: 'alert',
        description: 'Dalda Oil is completely out of stock and Super Basmati Rice has only 2 bags remaining. Reorder today to prevent lost sales.',
        urduTranslation: 'ڈالڈا کوکنگ آئل ختم ہوچکا ہے اور باسمتی چاول کے صرف 2 بیگز باقی ہیں۔ فوری آرڈر کریں۔',
        severity: 'critical',
        metricValue: 0.0,
        metricLabel: 'Dalda Stock',
        createdAt: now,
      ),
      AiInsight(
        id: 'ins-3',
        title: 'Udhaar Collection Opportunity',
        type: 'action_tip',
        description: 'Kamran Traders & Haji Tariq have Rs 42,500 pending for >5 days. Send WhatsApp reminders today.',
        urduTranslation: 'کامران ٹریڈرز اور حاجی طارق کے 42,500 روپے 5 دن سے زائد سے واجب الادا ہیں۔ واٹس ایپ یاد دہانی بھیجیں۔',
        severity: 'warning',
        metricValue: 42500.0,
        metricLabel: 'Pending Total',
        createdAt: now,
      ),
    ]);
  }

  // ================= PRODUCTS CRUD =================
  Future<List<Product>> getProducts({String? query, bool? lowStockOnly}) async {
    final db = await database;
    if (db == null) {
      return _memProducts.where((p) {
        if (lowStockOnly == true && !p.isLowStock && !p.isOutOfStock) return false;
        if (query != null && query.trim().isNotEmpty) {
          final q = query.toLowerCase();
          return p.name.toLowerCase().contains(q) ||
              p.sku.toLowerCase().contains(q) ||
              p.barcode.toLowerCase().contains(q) ||
              p.categoryName.toLowerCase().contains(q);
        }
        return true;
      }).toList();
    }

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (lowStockOnly == true) {
      whereClause += '(stock_quantity <= low_stock_threshold)';
    }

    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim().toLowerCase()}%';
      final searchPart = '(LOWER(name) LIKE ? OR LOWER(sku) LIKE ? OR barcode LIKE ? OR LOWER(category_name) LIKE ?)';
      if (whereClause.isNotEmpty) {
        whereClause += ' AND $searchPart';
      } else {
        whereClause = searchPart;
      }
      whereArgs.addAll([q, q, q, q]);
    }

    final maps = await db.query(
      'products',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'name ASC',
    );

    return maps.map((m) => Product.fromJson(m)).toList();
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await database;
    if (db == null) {
      try {
        return _memProducts.firstWhere((p) => p.barcode == barcode || p.sku == barcode);
      } catch (_) {
        return null;
      }
    }

    final maps = await db.query(
      'products',
      where: 'barcode = ? OR sku = ?',
      whereArgs: [barcode, barcode],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Product.fromJson(maps.first);
    }
    return null;
  }

  Future<int> insertProduct(Product product) async {
    final db = await database;
    if (db == null) {
      final newId = (_memProducts.isNotEmpty ? _memProducts.map((p) => p.id).reduce((a, b) => a > b ? a : b) : 0) + 1;
      final newProd = product.copyWith(id: newId);
      _memProducts.add(newProd);
      return newId;
    }
    return await db.insert('products', product.toSqlMap());
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    if (db == null) {
      final idx = _memProducts.indexWhere((p) => p.id == product.id);
      if (idx != -1) {
        _memProducts[idx] = product;
        return 1;
      }
      return 0;
    }
    return await db.update(
      'products',
      product.toSqlMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  // ================= CUSTOMERS CRUD =================
  Future<List<Customer>> getCustomers({String? query}) async {
    final db = await database;
    if (db == null) {
      if (query == null || query.isEmpty) return List.from(_memCustomers);
      final q = query.toLowerCase();
      return _memCustomers
          .where((c) => c.name.toLowerCase().contains(q) || c.phone.contains(q))
          .toList();
    }

    if (query != null && query.trim().isNotEmpty) {
      final q = '%${query.trim().toLowerCase()}%';
      final maps = await db.query(
        'customers',
        where: 'LOWER(name) LIKE ? OR phone LIKE ?',
        whereArgs: [q, q],
        orderBy: 'current_balance DESC, name ASC',
      );
      return maps.map((m) => Customer.fromJson(m)).toList();
    }

    final maps = await db.query(
      'customers',
      orderBy: 'current_balance DESC, name ASC',
    );
    return maps.map((m) => Customer.fromJson(m)).toList();
  }

  Future<int> insertCustomer(Customer customer) async {
    final db = await database;
    if (db == null) {
      final newId = (_memCustomers.isNotEmpty ? _memCustomers.map((c) => c.id).reduce((a, b) => a > b ? a : b) : 0) + 1;
      final newCust = customer.copyWith(id: newId);
      _memCustomers.add(newCust);
      return newId;
    }
    return await db.insert('customers', customer.toSqlMap());
  }

  Future<void> updateCustomerBalance(int customerId, double balanceDelta) async {
    final db = await database;
    if (db == null) {
      final idx = _memCustomers.indexWhere((c) => c.id == customerId);
      if (idx != -1) {
        final current = _memCustomers[idx];
        _memCustomers[idx] = current.copyWith(
          currentBalance: current.currentBalance + balanceDelta,
        );
      }
      return;
    }

    await db.rawUpdate(
      'UPDATE customers SET current_balance = current_balance + ? WHERE id = ?',
      [balanceDelta, customerId],
    );
  }

  // ================= SALES & POS =================
  Future<List<Sale>> getSales({int limit = 50}) async {
    final db = await database;
    if (db == null) {
      final sorted = List<Sale>.from(_memSales)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return sorted.take(limit).toList();
    }

    final saleMaps = await db.query(
      'sales',
      orderBy: 'created_at DESC',
      limit: limit,
    );

    List<Sale> sales = [];
    for (final sm in saleMaps) {
      final saleId = sm['id'] as int;
      final itemMaps = await db.query(
        'sale_items',
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );
      final items = itemMaps.map((im) => SaleItem.fromJson(im)).toList();
      final saleMapWithItems = Map<String, dynamic>.from(sm);
      saleMapWithItems['items'] = items.map((i) => i.toJson()).toList();
      sales.add(Sale.fromJson(saleMapWithItems));
    }

    return sales;
  }

  Future<int> createSale(Sale sale) async {
    final db = await database;
    if (db == null) {
      final newId = (_memSales.isNotEmpty ? _memSales.map((s) => s.id ?? 0).reduce((a, b) => a > b ? a : b) : 0) + 1;
      final newSale = Sale(
        id: newId,
        invoiceNumber: sale.invoiceNumber,
        customerId: sale.customerId,
        customerName: sale.customerName,
        totalAmount: sale.totalAmount,
        discountAmount: sale.discountAmount,
        taxAmount: sale.taxAmount,
        netAmount: sale.netAmount,
        paymentMethod: sale.paymentMethod,
        items: sale.items,
        createdAt: sale.createdAt,
        isSynced: false,
      );
      _memSales.insert(0, newSale);

      // Decrement memory stocks
      for (final item in sale.items) {
        final pIdx = _memProducts.indexWhere((p) => p.id == item.productId);
        if (pIdx != -1) {
          final cur = _memProducts[pIdx];
          _memProducts[pIdx] = cur.copyWith(
            stockQuantity: (cur.stockQuantity - item.quantity).clamp(0, 999999),
          );
        }
      }

      // If Udhaar, add balance & ledger
      if (sale.paymentMethod.toLowerCase() == 'udhaar' && sale.customerId != null) {
        await updateCustomerBalance(sale.customerId!, sale.netAmount);
        _memUdhaar.insert(
          0,
          UdhaarEntry(
            id: _memUdhaar.length + 1,
            customerId: sale.customerId!,
            customerName: sale.customerName,
            type: 'credit',
            amount: sale.netAmount,
            notes: 'Sale ${sale.invoiceNumber}',
            createdAt: sale.createdAt,
          ),
        );
      }

      return newId;
    }

    return await db.transaction<int>((txn) async {
      final saleId = await txn.insert('sales', sale.toSqlMap());

      for (final item in sale.items) {
        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': item.productId,
          'product_name': item.productName,
          'unit_price': item.unitPrice,
          'cost_price': item.costPrice,
          'quantity': item.quantity,
          'subtotal': item.subtotal,
        });

        // Decrement stock in database
        await txn.rawUpdate(
          'UPDATE products SET stock_quantity = MAX(0, stock_quantity - ?) WHERE id = ?',
          [item.quantity, item.productId],
        );
      }

      // If Udhaar, add to customer balance & create ledger entry
      if (sale.paymentMethod.toLowerCase() == 'udhaar' && sale.customerId != null) {
        await txn.rawUpdate(
          'UPDATE customers SET current_balance = current_balance + ? WHERE id = ?',
          [sale.netAmount, sale.customerId],
        );

        await txn.insert('udhaar_entries', {
          'customer_id': sale.customerId,
          'customer_name': sale.customerName,
          'type': 'credit',
          'amount': sale.netAmount,
          'notes': 'Sale Invoice: ${sale.invoiceNumber}',
          'created_at': sale.createdAt.toIso8601String(),
        });
      }

      return saleId;
    });
  }

  // ================= UDHAAR / KHATA LEDGER =================
  Future<List<UdhaarEntry>> getCustomerUdhaarHistory(int customerId) async {
    final db = await database;
    if (db == null) {
      final list = _memUdhaar.where((u) => u.customerId == customerId).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }

    final maps = await db.query(
      'udhaar_entries',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );

    return maps.map((m) => UdhaarEntry.fromJson(m)).toList();
  }

  Future<int> addUdhaarTransaction({
    required int customerId,
    required String customerName,
    required String type, // 'credit' or 'payment'
    required double amount,
    required String notes,
  }) async {
    final db = await database;
    final now = DateTime.now();
    final balanceDelta = type.toLowerCase() == 'credit' ? amount : -amount;

    if (db == null) {
      final newId = _memUdhaar.length + 1;
      _memUdhaar.insert(
        0,
        UdhaarEntry(
          id: newId,
          customerId: customerId,
          customerName: customerName,
          type: type,
          amount: amount,
          notes: notes,
          createdAt: now,
        ),
      );
      await updateCustomerBalance(customerId, balanceDelta);
      return newId;
    }

    return await db.transaction<int>((txn) async {
      final entryId = await txn.insert('udhaar_entries', {
        'customer_id': customerId,
        'customer_name': customerName,
        'type': type,
        'amount': amount,
        'notes': notes,
        'created_at': now.toIso8601String(),
      });

      await txn.rawUpdate(
        'UPDATE customers SET current_balance = current_balance + ? WHERE id = ?',
        [balanceDelta, customerId],
      );

      return entryId;
    });
  }

  // ================= AI INSIGHTS =================
  Future<List<AiInsight>> getAiInsights() async {
    final db = await database;
    if (db == null) return List.from(_memInsights);

    final maps = await db.query('ai_insights', orderBy: 'created_at DESC');
    return maps.map((m) => AiInsight.fromJson(m)).toList();
  }

  Future<void> replaceAiInsights(List<AiInsight> newInsights) async {
    final db = await database;
    if (db == null) {
      _memInsights.clear();
      _memInsights.addAll(newInsights);
      return;
    }

    await db.transaction((txn) async {
      await txn.delete('ai_insights');
      for (final ins in newInsights) {
        await txn.insert('ai_insights', ins.toJson());
      }
    });
  }

  // ================= DASHBOARD AGGREGATES =================
  Future<Map<String, dynamic>> getDashboardMetrics() async {
    final db = await database;
    if (db == null) {
      final today = DateTime.now();
      final todaySalesList = _memSales.where((s) =>
          s.createdAt.year == today.year &&
          s.createdAt.month == today.month &&
          s.createdAt.day == today.day).toList();

      final todaySalesTotal = todaySalesList.fold<double>(0.0, (acc, s) => acc + s.netAmount);
      final todayProfit = todaySalesList.fold<double>(0.0, (acc, s) => acc + s.calculatedTotalProfit);
      final pendingUdhaar = _memCustomers.fold<double>(0.0, (acc, c) => acc + c.currentBalance);
      final lowStockCount = _memProducts.where((p) => p.isLowStock || p.isOutOfStock).length;

      return {
        'today_sales': todaySalesTotal,
        'today_profit': todayProfit > 0 ? todayProfit : (todaySalesTotal * 0.18),
        'pending_udhaar': pendingUdhaar,
        'low_stock_count': lowStockCount,
      };
    }

    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    // Today sales
    final salesRes = await db.rawQuery('''
      SELECT SUM(net_amount) as total_sales, COUNT(*) as count 
      FROM sales 
      WHERE created_at LIKE ?
    ''', ['$todayStr%']);
    final todaySales = (salesRes.first['total_sales'] as num?)?.toDouble() ?? 0.0;

    // Today profit calculated from sale_items
    final profitRes = await db.rawQuery('''
      SELECT SUM((si.unit_price - si.cost_price) * si.quantity) as raw_profit
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      WHERE s.created_at LIKE ?
    ''', ['$todayStr%']);
    final rawProfit = (profitRes.first['raw_profit'] as num?)?.toDouble() ?? (todaySales * 0.18);

    // Pending Udhaar
    final udhaarRes = await db.rawQuery('''
      SELECT SUM(current_balance) as total_udhaar 
      FROM customers 
      WHERE current_balance > 0
    ''');
    final pendingUdhaar = (udhaarRes.first['total_udhaar'] as num?)?.toDouble() ?? 0.0;

    // Low stock count
    final stockRes = await db.rawQuery('''
      SELECT COUNT(*) as low_count 
      FROM products 
      WHERE stock_quantity <= low_stock_threshold
    ''');
    final lowStockCount = (stockRes.first['low_count'] as int?) ?? 0;

    return {
      'today_sales': todaySales,
      'today_profit': rawProfit,
      'pending_udhaar': pendingUdhaar,
      'low_stock_count': lowStockCount,
    };
  }
}
