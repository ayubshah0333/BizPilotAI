import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sale.dart';
import '../models/ai_insight.dart';
import '../services/api_service.dart';
import '../services/whatsapp_service.dart';
import '../services/printer_service.dart';
import '../theme/theme.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onNavigateToPos;
  final VoidCallback onNavigateToInventory;
  final VoidCallback onNavigateToUdhaar;
  final VoidCallback onNavigateToInsights;
  final VoidCallback onOpenSettings;

  const DashboardScreen({
    super.key,
    required this.onNavigateToPos,
    required this.onNavigateToInventory,
    required this.onNavigateToUdhaar,
    required this.onNavigateToInsights,
    required this.onOpenSettings,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  String _businessName = 'BizPilot Store';
  String _currency = 'PKR';
  bool _isOffline = false;

  Map<String, dynamic> _metrics = {
    'today_sales': 0.0,
    'today_profit': 0.0,
    'pending_udhaar': 0.0,
    'low_stock_count': 0,
  };

  List<Sale> _recentSales = [];
  List<AiInsight> _insights = [];
  bool _showUrduInsights = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    final bName = await ApiService.instance.getBusinessName();
    final curr = await ApiService.instance.getCurrency();
    final offline = await ApiService.instance.isOfflineMode();
    final metrics = await ApiService.instance.fetchDashboardMetrics();
    final sales = await ApiService.instance.fetchSales(limit: 6);
    final insights = await ApiService.instance.fetchAiInsights();

    if (mounted) {
      setState(() {
        _businessName = bName;
        _currency = curr;
        _isOffline = offline;
        _metrics = metrics;
        _recentSales = sales;
        _insights = insights;
        _isLoading = false;
      });
    }
  }

  String _formatAmount(double amount) {
    final formatter = NumberFormat('#,##0.00');
    return '$_currency ${formatter.format(amount)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 14, top: 8, bottom: 8, right: 2),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset('assets/images/app_logo.png', fit: BoxFit.cover),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _businessName,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isOffline ? AppColors.amberWarning : AppColors.emeraldSuccess,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isOffline ? 'Offline Mode (Local Storage)' : 'Live Synced • Ready',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _isOffline ? AppColors.amberWarning : AppColors.slate500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Data',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.slate700),
            onPressed: _loadDashboardData,
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined, color: AppColors.slate700),
            onPressed: widget.onOpenSettings,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAiInsightsBanner(),
                    const SizedBox(height: 16),
                    _buildMetricsGrid(),
                    const SizedBox(height: 20),
                    _buildQuickActions(),
                    const SizedBox(height: 24),
                    _buildRecentSalesSection(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAiInsightsBanner() {
    if (_insights.isEmpty) {
      return const SizedBox.shrink();
    }

    final topInsight = _insights.first;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.slate900,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.indigoPrimary.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.indigoPrimary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'AI Diagnostic Alert',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  setState(() => _showUrduInsights = !_showUrduInsights);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.translate, size: 13, color: Colors.white70),
                      const SizedBox(width: 5),
                      Text(
                        _showUrduInsights ? 'English' : 'اردو',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            topInsight.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _showUrduInsights ? topInsight.urduTranslation : topInsight.description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: widget.onNavigateToInsights,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.indigoLight),
              label: const Text(
                'View All AI Analytics',
                style: TextStyle(color: AppColors.indigoLight, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    final todaySales = (_metrics['today_sales'] as num?)?.toDouble() ?? 0.0;
    final todayProfit = (_metrics['today_profit'] as num?)?.toDouble() ?? 0.0;
    final pendingUdhaar = (_metrics['pending_udhaar'] as num?)?.toDouble() ?? 0.0;
    final lowStockCount = (_metrics['low_stock_count'] as int?) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Financial Overview',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.25,
          children: [
            _buildMetricCard(
              title: "Today's Sales",
              value: _formatAmount(todaySales),
              icon: Icons.point_of_sale_rounded,
              color: AppColors.indigoPrimary,
              bgColor: AppColors.indigoSubtle,
            ),
            _buildMetricCard(
              title: 'Net Profit',
              value: _formatAmount(todayProfit),
              icon: Icons.trending_up_rounded,
              color: AppColors.emeraldSuccess,
              bgColor: AppColors.emeraldSubtle,
            ),
            _buildMetricCard(
              title: 'Udhaar Receivables',
              value: _formatAmount(pendingUdhaar),
              icon: Icons.account_balance_wallet_outlined,
              color: AppColors.roseDanger,
              bgColor: AppColors.roseSubtle,
              badge: pendingUdhaar > 0 ? 'Pending' : 'Clear',
            ),
            _buildMetricCard(
              title: 'Low Stock Items',
              value: '$lowStockCount Items',
              icon: Icons.inventory_2_outlined,
              color: lowStockCount > 0 ? AppColors.amberWarning : AppColors.slate600,
              bgColor: lowStockCount > 0 ? AppColors.amberSubtle : AppColors.slate100,
              badge: lowStockCount > 0 ? 'Restock Soon' : 'Optimal',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
    String? badge,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              if (badge != null)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: AppColors.slate500, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate900,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Operations',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                label: 'POS Sale',
                subtitle: 'New Invoice',
                icon: Icons.add_shopping_cart_rounded,
                color: AppColors.indigoPrimary,
                onTap: widget.onNavigateToPos,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildQuickActionButton(
                label: 'Products',
                subtitle: 'Inventory',
                icon: Icons.qr_code_scanner_rounded,
                color: AppColors.emeraldSuccess,
                onTap: widget.onNavigateToInventory,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildQuickActionButton(
                label: 'Khata',
                subtitle: 'Udhaar Ledger',
                icon: Icons.menu_book_rounded,
                color: AppColors.roseDanger,
                onTap: widget.onNavigateToUdhaar,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.slate900),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.slate500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSalesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Invoices',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.slate900),
            ),
            TextButton(
              onPressed: widget.onNavigateToPos,
              child: const Text('New Sale +'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_recentSales.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.slate200),
            ),
            child: const Text(
              'No sales recorded yet. Tap "POS Sale" to start billing!',
              style: TextStyle(color: AppColors.slate500, fontSize: 13),
            ),
          )
        else
          ListView.separated(
            itemCount: _recentSales.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final sale = _recentSales[index];
              final isUdhaar = sale.paymentMethod.toLowerCase() == 'udhaar';
              final timeStr = DateFormat('hh:mm a, dd MMM').format(sale.createdAt);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isUdhaar ? AppColors.roseSubtle : AppColors.indigoSubtle,
                      child: Icon(
                        isUdhaar ? Icons.account_balance_wallet_outlined : Icons.receipt_long_rounded,
                        color: isUdhaar ? AppColors.roseDanger : AppColors.indigoPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  sale.customerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isUdhaar ? AppColors.roseSubtle : AppColors.emeraldSubtle,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  sale.paymentMethod,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isUdhaar ? AppColors.roseDanger : AppColors.emeraldSuccess,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${sale.invoiceNumber} • $timeStr',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _formatAmount(sale.netAmount),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.slate900,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                PrinterService.printThermalReceipt(
                                  context: context,
                                  sale: sale,
                                  businessName: _businessName,
                                  currency: _currency,
                                );
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.print_outlined, size: 12, color: AppColors.indigoPrimary),
                                    SizedBox(width: 3),
                                    Text(
                                      'Print',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.indigoPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () {
                                WhatsAppService.launchWhatsApp(
                                  message: WhatsAppService.formatInvoiceText(
                                    sale: sale,
                                    businessName: _businessName,
                                    currency: _currency,
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.share, size: 12, color: AppColors.emeraldSuccess),
                                    SizedBox(width: 3),
                                    Text(
                                      'WhatsApp',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.emeraldSuccess,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
