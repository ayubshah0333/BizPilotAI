import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/sale.dart';
import '../models/udhaar_entry.dart';
import '../models/ai_insight.dart';
import 'database_service.dart';

class ApiService {
  static final ApiService instance = ApiService._init();
  ApiService._init();

  static const String _defaultUrl = 'http://localhost/BizPilotAI/backend/api';
  static const Duration _timeout = Duration(seconds: 4);

  Future<SharedPreferences> get _prefs async => await SharedPreferences.getInstance();

  Future<String> getBaseUrl() async {
    final prefs = await _prefs;
    final saved = prefs.getString('api_base_url');
    if (saved != null && saved.isNotEmpty) return saved;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Connects via ADB reverse port 8080 or fallback
      return 'http://localhost:8080/BizPilotAI/backend/api';
    }
    return _defaultUrl;
  }

  Future<void> setBaseUrl(String url) async {
    final prefs = await _prefs;
    await prefs.setString('api_base_url', url.trim());
  }

  Future<bool> isOfflineMode() async {
    final prefs = await _prefs;
    return prefs.getBool('offline_mode') ?? false;
  }

  Future<void> setOfflineMode(bool offline) async {
    final prefs = await _prefs;
    await prefs.setBool('offline_mode', offline);
  }

  Future<String> getBusinessName() async {
    final prefs = await _prefs;
    return prefs.getString('business_name') ?? 'Al-Madina Super Store';
  }

  Future<void> setBusinessName(String name) async {
    final prefs = await _prefs;
    await prefs.setString('business_name', name);
  }

  Future<String> getCurrency() async {
    final prefs = await _prefs;
    return prefs.getString('currency') ?? 'PKR';
  }

  Future<void> setCurrency(String curr) async {
    final prefs = await _prefs;
    await prefs.setString('currency', curr);
  }

  Future<double> getTaxRate() async {
    final prefs = await _prefs;
    return prefs.getDouble('tax_rate') ?? 0.0;
  }

  Future<void> setTaxRate(double rate) async {
    final prefs = await _prefs;
    await prefs.setDouble('tax_rate', rate);
  }

  // ================= DASHBOARD =================
  Future<Map<String, dynamic>> fetchDashboardMetrics() async {
    if (await isOfflineMode()) {
      return await DatabaseService.instance.getDashboardMetrics();
    }

    try {
      final baseUrl = await getBaseUrl();
      final uri = Uri.parse('$baseUrl/dashboard.php');
      final res = await http.get(uri).timeout(_timeout);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is Map<String, dynamic> && data['success'] == true && data['data'] != null) {
          return Map<String, dynamic>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint('ApiService.fetchDashboardMetrics failed, fallback to local DB: $e');
    }

    return await DatabaseService.instance.getDashboardMetrics();
  }

  // ================= PRODUCTS =================
  Future<List<Product>> fetchProducts({String? query, bool? lowStockOnly}) async {
    if (await isOfflineMode()) {
      return await DatabaseService.instance.getProducts(query: query, lowStockOnly: lowStockOnly);
    }

    try {
      final baseUrl = await getBaseUrl();
      final queryParams = <String, String>{};
      if (query != null && query.isNotEmpty) queryParams['search'] = query;
      if (lowStockOnly == true) queryParams['low_stock'] = '1';

      final uri = Uri.parse('$baseUrl/products.php').replace(queryParameters: queryParams.isEmpty ? null : queryParams);
      final res = await http.get(uri).timeout(_timeout);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        List list = [];
        if (data is List) {
          list = data;
        } else if (data is Map && data['data'] is List) {
          list = data['data'];
        }
        return list.map((item) => Product.fromJson(Map<String, dynamic>.from(item))).toList();
      }
    } catch (e) {
      debugPrint('ApiService.fetchProducts failed, fallback to local DB: $e');
    }

    return await DatabaseService.instance.getProducts(query: query, lowStockOnly: lowStockOnly);
  }

  Future<bool> saveProduct(Product product) async {
    // Always save to local DB first
    if (product.id == 0) {
      await DatabaseService.instance.insertProduct(product);
    } else {
      await DatabaseService.instance.updateProduct(product);
    }

    if (await isOfflineMode()) return true;

    try {
      final baseUrl = await getBaseUrl();
      final uri = Uri.parse('$baseUrl/products.php');
      await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(product.toJson()),
      ).timeout(_timeout);
      return true;
    } catch (e) {
      debugPrint('ApiService.saveProduct remote sync failed (stored locally): $e');
      return true;
    }
  }

  // ================= CUSTOMERS =================
  Future<List<Customer>> fetchCustomers({String? query}) async {
    if (await isOfflineMode()) {
      return await DatabaseService.instance.getCustomers(query: query);
    }

    try {
      final baseUrl = await getBaseUrl();
      final uri = Uri.parse('$baseUrl/customers.php${query != null && query.isNotEmpty ? '?search=$query' : ''}');
      final res = await http.get(uri).timeout(_timeout);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        List list = [];
        if (data is List) {
          list = data;
        } else if (data is Map && data['data'] is List) {
          list = data['data'];
        }
        return list.map((c) => Customer.fromJson(Map<String, dynamic>.from(c))).toList();
      }
    } catch (e) {
      debugPrint('ApiService.fetchCustomers failed, fallback to local DB: $e');
    }

    return await DatabaseService.instance.getCustomers(query: query);
  }

  Future<bool> saveCustomer(Customer customer) async {
    await DatabaseService.instance.insertCustomer(customer);

    if (await isOfflineMode()) return true;

    try {
      final baseUrl = await getBaseUrl();
      final uri = Uri.parse('$baseUrl/customers.php');
      await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(customer.toJson()),
      ).timeout(_timeout);
      return true;
    } catch (e) {
      debugPrint('ApiService.saveCustomer remote sync failed (stored locally): $e');
      return true;
    }
  }

  // ================= SALES / POS =================
  Future<List<Sale>> fetchSales({int limit = 50}) async {
    if (await isOfflineMode()) {
      return await DatabaseService.instance.getSales(limit: limit);
    }

    try {
      final baseUrl = await getBaseUrl();
      final uri = Uri.parse('$baseUrl/sales.php?limit=$limit');
      final res = await http.get(uri).timeout(_timeout);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        List list = [];
        if (data is List) {
          list = data;
        } else if (data is Map && data['data'] is List) {
          list = data['data'];
        }
        return list.map((s) => Sale.fromJson(Map<String, dynamic>.from(s))).toList();
      }
    } catch (e) {
      debugPrint('ApiService.fetchSales failed, fallback to local DB: $e');
    }

    return await DatabaseService.instance.getSales(limit: limit);
  }

  Future<bool> createSale(Sale sale) async {
    // 1. Always record locally immediately
    await DatabaseService.instance.createSale(sale);

    if (await isOfflineMode()) return true;

    // 2. Attempt remote sync
    try {
      final baseUrl = await getBaseUrl();
      final uri = Uri.parse('$baseUrl/sales.php');
      await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(sale.toJson()),
      ).timeout(_timeout);
      return true;
    } catch (e) {
      debugPrint('ApiService.createSale remote sync queued locally: $e');
      return true;
    }
  }

  // ================= UDHAAR / KHATA LEDGER =================
  Future<List<UdhaarEntry>> fetchCustomerUdhaarHistory(int customerId) async {
    if (await isOfflineMode()) {
      return await DatabaseService.instance.getCustomerUdhaarHistory(customerId);
    }

    try {
      final baseUrl = await getBaseUrl();
      final uri = Uri.parse('$baseUrl/udhaar.php?customer_id=$customerId');
      final res = await http.get(uri).timeout(_timeout);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        List list = [];
        if (data is List) {
          list = data;
        } else if (data is Map && data['data'] is List) {
          list = data['data'];
        }
        return list.map((u) => UdhaarEntry.fromJson(Map<String, dynamic>.from(u))).toList();
      }
    } catch (e) {
      debugPrint('ApiService.fetchCustomerUdhaarHistory fallback to local DB: $e');
    }

    return await DatabaseService.instance.getCustomerUdhaarHistory(customerId);
  }

  Future<bool> addUdhaarTransaction({
    required int customerId,
    required String customerName,
    required String type,
    required double amount,
    required String notes,
  }) async {
    await DatabaseService.instance.addUdhaarTransaction(
      customerId: customerId,
      customerName: customerName,
      type: type,
      amount: amount,
      notes: notes,
    );

    if (await isOfflineMode()) return true;

    try {
      final baseUrl = await getBaseUrl();
      final uri = Uri.parse('$baseUrl/udhaar.php');
      await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'customer_id': customerId,
          'customer_name': customerName,
          'type': type,
          'amount': amount,
          'notes': notes,
        }),
      ).timeout(_timeout);
      return true;
    } catch (e) {
      debugPrint('ApiService.addUdhaarTransaction queued locally: $e');
      return true;
    }
  }

  // ================= AI INSIGHTS =================
  Future<List<AiInsight>> fetchAiInsights() async {
    if (await isOfflineMode()) {
      return await DatabaseService.instance.getAiInsights();
    }

    try {
      final baseUrl = await getBaseUrl();
      final uri = Uri.parse('$baseUrl/insights.php');
      final res = await http.get(uri).timeout(_timeout);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        List list = [];
        if (data is List) {
          list = data;
        } else if (data is Map && data['data'] is List) {
          list = data['data'];
        }
        final parsed = list.map((i) => AiInsight.fromJson(Map<String, dynamic>.from(i))).toList();
        if (parsed.isNotEmpty) {
          await DatabaseService.instance.replaceAiInsights(parsed);
          return parsed;
        }
      }
    } catch (e) {
      debugPrint('ApiService.fetchAiInsights fallback to local DB: $e');
    }

    return await DatabaseService.instance.getAiInsights();
  }
}
