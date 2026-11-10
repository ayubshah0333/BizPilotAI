import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/sale.dart';
import '../models/sale_item.dart';
import '../services/api_service.dart';
import '../services/whatsapp_service.dart';
import '../services/printer_service.dart';
import '../widgets/camera_barcode_scanner.dart';
import '../theme/theme.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get subtotal => product.sellingPrice * quantity;
}

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  List<Customer> _customers = [];

  final List<CartItem> _cart = [];
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];

  bool _isLoading = true;
  String _currency = 'PKR';
  String _businessName = 'BizPilot Store';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    final curr = await ApiService.instance.getCurrency();
    final bName = await ApiService.instance.getBusinessName();
    final prods = await ApiService.instance.fetchProducts();
    final custs = await ApiService.instance.fetchCustomers();

    final cats = {'All', ...prods.map((p) => p.categoryName)}.toList();

    if (mounted) {
      setState(() {
        _currency = curr;
        _businessName = bName;
        _allProducts = prods;
        _filteredProducts = prods;
        _customers = custs;
        _categories = cats;
        _isLoading = false;
      });
    }
  }

  void _filterProducts(String query) {
    setState(() {
      _filteredProducts = _allProducts.where((p) {
        final matchesCat = _selectedCategory == 'All' || p.categoryName == _selectedCategory;
        if (!matchesCat) return false;
        if (query.isEmpty) return true;
        final q = query.toLowerCase();
        return p.name.toLowerCase().contains(q) ||
            p.sku.toLowerCase().contains(q) ||
            p.barcode.toLowerCase().contains(q);
      }).toList();
    });
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
      _filterProducts(_searchController.text);
    });
  }

  void _addToCart(Product product) {
    if (product.isOutOfStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} is out of stock!'),
          backgroundColor: AppColors.roseDanger,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      final existingIndex = _cart.indexWhere((item) => item.product.id == product.id);
      if (existingIndex != -1) {
        if (_cart[existingIndex].quantity < product.stockQuantity) {
          _cart[existingIndex].quantity++;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot exceed stock quantity (${product.stockQuantity})!'),
              backgroundColor: AppColors.amberWarning,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        _cart.add(CartItem(product: product, quantity: 1));
      }
    });
  }

  void _updateCartQuantity(int index, int delta) {
    setState(() {
      final item = _cart[index];
      final newQty = item.quantity + delta;
      if (newQty <= 0) {
        _cart.removeAt(index);
      } else if (newQty <= item.product.stockQuantity) {
        item.quantity = newQty;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Max available stock is ${item.product.stockQuantity}'),
            backgroundColor: AppColors.amberWarning,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    });
  }

  void _handleBarcodeSubmit(String code) {
    if (code.trim().isEmpty) return;
    final match = _allProducts.firstWhere(
      (p) => p.barcode == code.trim() || p.sku.toLowerCase() == code.trim().toLowerCase(),
      orElse: () => const Product(id: 0, name: '', sku: '', barcode: '', costPrice: 0, sellingPrice: 0, stockQuantity: 0),
    );

    if (match.id != 0) {
      _addToCart(match);
      _barcodeController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${match.name}" to cart'),
          backgroundColor: AppColors.emeraldSuccess,
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No item found with barcode/SKU: $code'),
          backgroundColor: AppColors.roseDanger,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  double get _cartSubtotal => _cart.fold(0.0, (acc, item) => acc + item.subtotal);
  int get _cartItemCount => _cart.fold(0, (acc, item) => acc + item.quantity);

  String _formatAmount(double amount) {
    return '$_currency ${NumberFormat('#,##0.00').format(amount)}';
  }

  void _showCheckoutDialog() {
    if (_cart.isEmpty) return;

    Customer? selectedCustomer;
    String paymentMethod = 'Cash'; // 'Cash' or 'Udhaar'
    double discount = 0.0;
    final discountController = TextEditingController(text: '0');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final netTotal = (_cartSubtotal - discount).clamp(0.0, double.infinity);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Checkout & Billing',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 10),

                    // Customer Selector
                    const Text('Select Customer', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.slate300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Customer?>(
                          isExpanded: true,
                          value: selectedCustomer,
                          hint: const Text('Walk-in Customer (Cash Only)'),
                          items: [
                            const DropdownMenuItem<Customer?>(
                              value: null,
                              child: Text('Walk-in Customer'),
                            ),
                            ..._customers.map((c) {
                              return DropdownMenuItem<Customer?>(
                                value: c,
                                child: Text('${c.name} (${c.phone}) - Udhaar: $_currency ${c.currentBalance.toStringAsFixed(0)}'),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setSheetState(() {
                              selectedCustomer = val;
                              if (val == null) {
                                paymentMethod = 'Cash';
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Payment Method (Cash vs Udhaar)
                    const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setSheetState(() => paymentMethod = 'Cash'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: paymentMethod == 'Cash' ? AppColors.indigoPrimary : AppColors.slate100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: paymentMethod == 'Cash' ? AppColors.indigoPrimary : AppColors.slate300,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '💵 Cash',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: paymentMethod == 'Cash' ? Colors.white : AppColors.slate700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              if (selectedCustomer == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please select a registered Customer for Udhaar!'),
                                    backgroundColor: AppColors.amberWarning,
                                  ),
                                );
                                return;
                              }
                              setSheetState(() => paymentMethod = 'Udhaar');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: paymentMethod == 'Udhaar' ? AppColors.roseDanger : AppColors.slate100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: paymentMethod == 'Udhaar' ? AppColors.roseDanger : AppColors.slate300,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '📖 Udhaar / Khata',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: paymentMethod == 'Udhaar' ? Colors.white : AppColors.slate700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Discount Field
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: discountController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Discount ($_currency)',
                              prefixIcon: const Icon(Icons.discount_outlined),
                            ),
                            onChanged: (val) {
                              setSheetState(() {
                                discount = double.tryParse(val) ?? 0.0;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Order Summary Box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.slate50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.slate200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Subtotal', style: TextStyle(color: AppColors.slate600)),
                              Text(_formatAmount(_cartSubtotal), style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                          if (discount > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Discount', style: TextStyle(color: AppColors.roseDanger)),
                                Text('- ${_formatAmount(discount)}', style: const TextStyle(color: AppColors.roseDanger, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Net Payable', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(
                                _formatAmount(netTotal),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.indigoPrimary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Complete Sale Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: paymentMethod == 'Udhaar' ? AppColors.roseDanger : AppColors.indigoPrimary,
                        ),
                        onPressed: () async {
                          final invNum = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
                          final newSale = Sale(
                            invoiceNumber: invNum,
                            customerId: selectedCustomer?.id,
                            customerName: selectedCustomer?.name ?? 'Walk-in Customer',
                            totalAmount: _cartSubtotal,
                            discountAmount: discount,
                            taxAmount: 0.0,
                            netAmount: netTotal,
                            paymentMethod: paymentMethod,
                            items: _cart.map((c) => SaleItem(
                              productId: c.product.id,
                              productName: c.product.name,
                              unitPrice: c.product.sellingPrice,
                              costPrice: c.product.costPrice,
                              quantity: c.quantity,
                              subtotal: c.subtotal,
                            )).toList(),
                            createdAt: DateTime.now(),
                          );

                          Navigator.pop(ctx);
                          await _finalizeSale(newSale, selectedCustomer);
                        },
                        child: Text(
                          paymentMethod == 'Udhaar' ? 'Record Udhaar & Issue Bill' : 'Complete Cash Sale',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _finalizeSale(Sale sale, Customer? customer) async {
    await ApiService.instance.createSale(sale);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.emeraldSuccess, size: 28),
              const SizedBox(width: 8),
              const Text('Sale Complete!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Invoice: ${sale.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Customer: ${sale.customerName}'),
              Text('Net Total: ${_formatAmount(sale.netAmount)}'),
              Text('Payment: ${sale.paymentMethod}'),
              const SizedBox(height: 12),
              const Text(
                'Would you like to share the receipt via WhatsApp with the customer?',
                style: TextStyle(fontSize: 13, color: AppColors.slate600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                setState(() => _cart.clear());
                _loadInitialData();
              },
              child: const Text('Done'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.print_rounded, size: 16),
              label: const Text('Print Receipt'),
              onPressed: () {
                PrinterService.printThermalReceipt(
                  context: context,
                  sale: sale,
                  businessName: _businessName,
                  currency: _currency,
                );
              },
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldSuccess),
              icon: const Icon(Icons.share, size: 16),
              label: const Text('WhatsApp Invoice'),
              onPressed: () {
                final message = WhatsAppService.formatInvoiceText(
                  sale: sale,
                  businessName: _businessName,
                  currency: _currency,
                );
                WhatsAppService.launchWhatsApp(
                  phone: customer?.phone,
                  message: message,
                );
                Navigator.pop(dialogCtx);
                setState(() => _cart.clear());
                _loadInitialData();
              },
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POS & Smart Billing', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Live Camera Barcode Scanner',
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.indigoPrimary),
            onPressed: () async {
              final code = await CameraBarcodeScanner.scan(context);
              if (code != null && code.isNotEmpty) {
                _handleBarcodeSubmit(code);
              }
            },
          ),
          IconButton(
            tooltip: 'Manual Barcode Entry',
            icon: const Icon(Icons.keyboard_alt_outlined, color: AppColors.slate700),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Scan or Enter Barcode'),
                  content: TextField(
                    controller: _barcodeController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Enter barcode or SKU (e.g. 8961014101)',
                      prefixIcon: Icon(Icons.qr_code),
                    ),
                    onSubmitted: (val) {
                      Navigator.pop(ctx);
                      _handleBarcodeSubmit(val);
                    },
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleBarcodeSubmit(_barcodeController.text);
                      },
                      child: const Text('Add Item'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterProducts,
                    decoration: InputDecoration(
                      hintText: 'Search products by name, SKU or barcode...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.slate400),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.indigoPrimary),
                            tooltip: 'Camera Scan',
                            onPressed: () async {
                              final code = await CameraBarcodeScanner.scan(context);
                              if (code != null && code.isNotEmpty) {
                                _handleBarcodeSubmit(code);
                              }
                            },
                          ),
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _filterProducts('');
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Category chips
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = cat == _selectedCategory;
                      return ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (_) => _onCategorySelected(cat),
                        selectedColor: AppColors.indigoPrimary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.slate700,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // Products Grid
                Expanded(
                  child: _filteredProducts.isEmpty
                      ? const Center(
                          child: Text(
                            'No matching products found',
                            style: TextStyle(color: AppColors.slate500),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.95,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            final p = _filteredProducts[index];
                            return _buildProductCard(p);
                          },
                        ),
                ),

                // Bottom Cart Summary Bar
                _buildCartBar(),
              ],
            ),
    );
  }

  Widget _buildProductCard(Product product) {
    final isInCart = _cart.any((item) => item.product.id == product.id);

    return InkWell(
      onTap: () => _addToCart(product),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isInCart ? AppColors.indigoPrimary : AppColors.slate200,
            width: isInCart ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.slate100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    product.categoryName,
                    style: const TextStyle(fontSize: 10, color: AppColors.slate600, fontWeight: FontWeight.w600),
                  ),
                ),
                _buildStockBadge(product),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slate900),
              ),
            ),
            Text(
              'SKU: ${product.sku}',
              style: const TextStyle(fontSize: 11, color: AppColors.slate400),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatAmount(product.sellingPrice),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.indigoPrimary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: product.isOutOfStock ? AppColors.slate200 : AppColors.indigoSubtle,
                  child: Icon(
                    Icons.add,
                    size: 16,
                    color: product.isOutOfStock ? AppColors.slate400 : AppColors.indigoPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockBadge(Product product) {
    if (product.isOutOfStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.roseSubtle,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Out',
          style: TextStyle(fontSize: 10, color: AppColors.roseDanger, fontWeight: FontWeight.bold),
        ),
      );
    }
    if (product.isLowStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.amberSubtle,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'Qty: ${product.stockQuantity}',
          style: const TextStyle(fontSize: 10, color: AppColors.amberWarning, fontWeight: FontWeight.bold),
        ),
      );
    }
    return Text(
      'Qty: ${product.stockQuantity}',
      style: const TextStyle(fontSize: 10, color: AppColors.slate500),
    );
  }

  Widget _buildCartBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.slate200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            InkWell(
              onTap: _showCartDrawer,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.indigoSubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shopping_bag_outlined, color: AppColors.indigoPrimary),
                  ),
                  if (_cartItemCount > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: AppColors.roseDanger,
                        child: Text(
                          '$_cartItemCount',
                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Total Payable', style: TextStyle(fontSize: 11, color: AppColors.slate500)),
                  Text(
                    _formatAmount(_cartSubtotal),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slate900,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _cart.isEmpty ? null : _showCheckoutDialog,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              child: const Text('Checkout →', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCartDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Cart Items (${_cart.length})',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      if (_cart.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() => _cart.clear());
                            setModalState(() {});
                            Navigator.pop(ctx);
                          },
                          child: const Text('Clear All', style: TextStyle(color: AppColors.roseDanger)),
                        ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: _cart.isEmpty
                        ? const Center(
                            child: Text('Your cart is currently empty.', style: TextStyle(color: AppColors.slate500)),
                          )
                        : ListView.separated(
                            itemCount: _cart.length,
                            separatorBuilder: (_, _) => const Divider(),
                            itemBuilder: (context, index) {
                              final item = _cart[index];
                              return Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text(
                                          '${_formatAmount(item.product.sellingPrice)} each',
                                          style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                                        onPressed: () {
                                          _updateCartQuantity(index, -1);
                                          setModalState(() {});
                                          setState(() {});
                                        },
                                      ),
                                      Text(
                                        '${item.quantity}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline, size: 20),
                                        onPressed: () {
                                          _updateCartQuantity(index, 1);
                                          setModalState(() {});
                                          setState(() {});
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatAmount(item.subtotal),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                  const Divider(),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _cart.isEmpty
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              _showCheckoutDialog();
                            },
                      child: Text('Proceed to Checkout (${_formatAmount(_cartSubtotal)})'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
