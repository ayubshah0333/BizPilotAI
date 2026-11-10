import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../widgets/camera_barcode_scanner.dart';
import '../theme/theme.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Product> _products = [];
  bool _isLoading = true;
  bool _lowStockFilter = false;
  String _currency = 'PKR';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);

    final curr = await ApiService.instance.getCurrency();
    final prods = await ApiService.instance.fetchProducts(
      query: _searchController.text.trim(),
      lowStockOnly: _lowStockFilter ? true : null,
    );

    if (mounted) {
      setState(() {
        _currency = curr;
        _products = prods;
        _isLoading = false;
      });
    }
  }

  String _formatAmount(double amount) {
    return '$_currency ${NumberFormat('#,##0.00').format(amount)}';
  }

  void _showAddEditProductDialog([Product? existingProduct]) {
    final isEditing = existingProduct != null;

    final nameController = TextEditingController(text: existingProduct?.name ?? '');
    final skuController = TextEditingController(text: existingProduct?.sku ?? '');
    final barcodeController = TextEditingController(text: existingProduct?.barcode ?? '');
    final costController = TextEditingController(text: existingProduct != null ? existingProduct.costPrice.toStringAsFixed(0) : '');
    final priceController = TextEditingController(text: existingProduct != null ? existingProduct.sellingPrice.toStringAsFixed(0) : '');
    final stockController = TextEditingController(text: existingProduct != null ? existingProduct.stockQuantity.toString() : '10');
    final thresholdController = TextEditingController(text: existingProduct != null ? existingProduct.lowStockThreshold.toString() : '5');
    String category = existingProduct?.categoryName ?? 'General';

    final categories = ['General', 'Grocery', 'Dairy', 'Beverages', 'Bakery', 'Household', 'Personal Care', 'Snacks'];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(isEditing ? 'Edit Product' : 'Add New Product'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Product Name *', hintText: 'e.g. Nestlé MilkPak 1L'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: skuController,
                              decoration: const InputDecoration(labelText: 'SKU Code', hintText: 'MLK-001'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: barcodeController,
                              decoration: InputDecoration(
                                labelText: 'Barcode',
                                hintText: '8961014101',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: AppColors.indigoPrimary),
                                  tooltip: 'Scan with Camera',
                                  onPressed: () async {
                                    final scanned = await CameraBarcodeScanner.scan(context);
                                    if (scanned != null && scanned.isNotEmpty) {
                                      setDialogState(() {
                                        barcodeController.text = scanned;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: categories.contains(category) ? category : categories.first,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => category = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: costController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(labelText: 'Cost Price ($_currency) *'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: priceController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(labelText: 'Selling Price ($_currency) *'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: stockController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Current Stock *'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: thresholdController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Low Stock Alert Qty'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter product name!')),
                      );
                      return;
                    }

                    final cost = double.tryParse(costController.text.trim()) ?? 0.0;
                    final price = double.tryParse(priceController.text.trim()) ?? 0.0;
                    final stock = int.tryParse(stockController.text.trim()) ?? 0;
                    final threshold = int.tryParse(thresholdController.text.trim()) ?? 5;

                    final updated = Product(
                      id: existingProduct?.id ?? 0,
                      name: nameController.text.trim(),
                      sku: skuController.text.trim().isEmpty ? 'SKU-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}' : skuController.text.trim(),
                      barcode: barcodeController.text.trim(),
                      costPrice: cost,
                      sellingPrice: price,
                      stockQuantity: stock,
                      lowStockThreshold: threshold,
                      categoryName: category,
                    );

                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    await ApiService.instance.saveProduct(updated);
                    _loadProducts();

                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(isEditing ? 'Product updated successfully' : 'Product added successfully'),
                          backgroundColor: AppColors.emeraldSuccess,
                        ),
                      );
                    }
                  },
                  child: Text(isEditing ? 'Update Product' : 'Save Product'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory & Stock', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.indigoPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showAddEditProductDialog(),
      ),
      body: Column(
        children: [
          // Search & Filter header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => _loadProducts(),
                    decoration: InputDecoration(
                      hintText: 'Search products by name, SKU or barcode...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.slate400),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _loadProducts();
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Low Stock'),
                  selected: _lowStockFilter,
                  selectedColor: AppColors.amberSubtle,
                  checkmarkColor: AppColors.amberWarning,
                  labelStyle: TextStyle(
                    color: _lowStockFilter ? AppColors.amberWarning : AppColors.slate700,
                    fontWeight: _lowStockFilter ? FontWeight.bold : FontWeight.w500,
                  ),
                  onSelected: (val) {
                    setState(() => _lowStockFilter = val);
                    _loadProducts();
                  },
                ),
              ],
            ),
          ),

          // Inventory List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.slate400),
                            const SizedBox(height: 12),
                            const Text(
                              'No products found matching criteria.',
                              style: TextStyle(color: AppColors.slate500),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => _showAddEditProductDialog(),
                              child: const Text('Add First Product'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadProducts,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _products.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final p = _products[index];
                            return _buildInventoryCard(p);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryCard(Product p) {
    Color badgeBg;
    Color badgeColor;
    String badgeText;

    if (p.isOutOfStock) {
      badgeBg = AppColors.roseSubtle;
      badgeColor = AppColors.roseDanger;
      badgeText = 'OUT OF STOCK';
    } else if (p.isLowStock) {
      badgeBg = AppColors.amberSubtle;
      badgeColor = AppColors.amberWarning;
      badgeText = 'LOW STOCK (${p.stockQuantity})';
    } else {
      badgeBg = AppColors.emeraldSubtle;
      badgeColor = AppColors.emeraldSuccess;
      badgeText = 'IN STOCK (${p.stockQuantity})';
    }

    return InkWell(
      onTap: () => _showAddEditProductDialog(p),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    p.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'SKU: ${p.sku}',
                  style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                ),
                if (p.barcode.isNotEmpty) ...[
                  const Text(' • ', style: TextStyle(color: AppColors.slate400)),
                  Text(
                    'Barcode: ${p.barcode}',
                    style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                  ),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.slate100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    p.categoryName,
                    style: const TextStyle(fontSize: 11, color: AppColors.slate600, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cost', style: TextStyle(fontSize: 11, color: AppColors.slate500)),
                    Text(
                      _formatAmount(p.costPrice),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.slate700),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Selling Price', style: TextStyle(fontSize: 11, color: AppColors.slate500)),
                    Text(
                      _formatAmount(p.sellingPrice),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.indigoPrimary),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Margin', style: TextStyle(fontSize: 11, color: AppColors.slate500)),
                    Text(
                      '${p.profitMargin.toStringAsFixed(1)}% (${_formatAmount(p.unitProfit)})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.emeraldSuccess),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
