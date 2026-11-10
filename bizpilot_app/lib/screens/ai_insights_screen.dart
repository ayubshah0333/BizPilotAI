import 'package:flutter/material.dart';
import '../models/ai_insight.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../theme/theme.dart';

class AiInsightsScreen extends StatefulWidget {
  const AiInsightsScreen({super.key});

  @override
  State<AiInsightsScreen> createState() => _AiInsightsScreenState();
}

class _AiInsightsScreenState extends State<AiInsightsScreen> {
  bool _isLoading = true;
  bool _isUrduMode = false;
  List<AiInsight> _insights = [];
  List<Product> _topProducts = [];
  List<Product> _lowStockProducts = [];
  String _currency = 'PKR';

  @override
  void initState() {
    super.initState();
    _loadInsightsData();
  }

  Future<void> _loadInsightsData() async {
    setState(() => _isLoading = true);

    final curr = await ApiService.instance.getCurrency();
    final insights = await ApiService.instance.fetchAiInsights();
    final allProducts = await ApiService.instance.fetchProducts();

    // Calculate Top 5 highest margin/revenue products
    final sortedByMargin = List<Product>.from(allProducts)
      ..sort((a, b) => b.unitProfit.compareTo(a.unitProfit));
    final top5 = sortedByMargin.take(5).toList();

    // Identify low stock products
    final lowStock = allProducts.where((p) => p.isLowStock || p.isOutOfStock).toList();

    if (mounted) {
      setState(() {
        _currency = curr;
        _insights = insights;
        _topProducts = top5;
        _lowStockProducts = lowStock;
        _isLoading = false;
      });
    }
  }

  Future<void> _runFreshAiScan() async {
    setState(() => _isLoading = true);

    // Simulate AI diagnostic scan
    await Future.delayed(const Duration(milliseconds: 600));
    final now = DateTime.now();

    final dynamicInsights = [
      AiInsight(
        id: 'ins-dyn-1',
        title: 'Weekly Sales Velocity & Momentum',
        type: 'trend',
        description: 'Sales velocity is up 18.4% compared to last cycle. Evening sales between 6 PM - 9 PM show peak customer traffic.',
        urduTranslation: 'گزشتہ ہفتے کے مقابلے میں فروخت کی رفتار میں 18.4 فیصد اضافہ ہوا ہے۔ شام 6 سے 9 بجے سب سے زیادہ گاہک آتے ہیں۔',
        severity: 'positive',
        metricValue: 18.4,
        metricLabel: 'Growth Rate',
        createdAt: now,
      ),
      AiInsight(
        id: 'ins-dyn-2',
        title: 'Urgent Restock Recommendation',
        type: 'alert',
        description: '${_lowStockProducts.length} items have fallen below safety thresholds. We recommend restocking 12 units of tea and 20 bags of rice immediately.',
        urduTranslation: '${_lowStockProducts.length} اشیاء محفوظ حد سے نیچے آچکی ہیں۔ چائے کے 12 یونٹ اور چاول کے 20 بیگز فوری منگوانے کی سفارش کی جاتی ہے۔',
        severity: 'critical',
        metricValue: _lowStockProducts.length.toDouble(),
        metricLabel: 'Urgent SKUs',
        createdAt: now,
      ),
      AiInsight(
        id: 'ins-dyn-3',
        title: 'Dead Stock & Slow Movers',
        type: 'dead_stock',
        description: 'Household detergents and specialty bakery items have had slower turnover (>14 days). Consider bundle offers with fast-selling dairy products.',
        urduTranslation: 'صفائی کے سامان اور کچھ بیکری آئٹمز کی فروخت سست ہے۔ انہیں ڈیری مصنوعات کے ساتھ رعایتی بنڈل میں فروخت کریں۔',
        severity: 'warning',
        metricValue: 14.0,
        metricLabel: 'Turnover Days',
        createdAt: now,
      ),
      AiInsight(
        id: 'ins-dyn-4',
        title: 'Cashflow Optimization & Udhaar Recovery',
        type: 'action_tip',
        description: 'Recovering outstanding balances from top 3 debtors will infuse over Rs 40,000 into liquid working capital for inventory purchases.',
        urduTranslation: 'اہم 3 گاہکوں سے بقایا رقم کی وصولی سے 40,000 روپے سے زائد فوری کیش فلو حاصل ہوگا جس سے نیا مال خریدا جا سکتا ہے۔',
        severity: 'info',
        metricValue: 40000.0,
        metricLabel: 'Recoverable',
        createdAt: now,
      ),
    ];

    await ApiService.instance.fetchAiInsights();
    if (mounted) {
      setState(() {
        _insights = dynamicInsights;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI Diagnostic Scan completed with updated business advice!'),
          backgroundColor: AppColors.indigoPrimary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Insights & Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // Urdu Language Switcher
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.slate100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                _buildLangButton(title: 'English', active: !_isUrduMode, onTap: () => setState(() => _isUrduMode = false)),
                _buildLangButton(title: 'اردو', active: _isUrduMode, onTap: () => setState(() => _isUrduMode = true)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Run AI Diagnostic',
            icon: const Icon(Icons.auto_awesome, color: AppColors.indigoPrimary),
            onPressed: _runFreshAiScan,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInsightsData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header AI Scanner Hero Banner
                    _buildAiScannerHero(),
                    const SizedBox(height: 20),

                    // Diagnostic Observations
                    Text(
                      _isUrduMode ? 'کاروباری مشورے اور تجزیہ' : 'Strategic Business Diagnostics',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.slate900),
                    ),
                    const SizedBox(height: 12),
                    ..._insights.map((insight) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildInsightCard(insight),
                        )),
                    const SizedBox(height: 16),

                    // Top 5 High Margin Items
                    Text(
                      _isUrduMode ? 'سب سے زیادہ منافع بخش اشیاء' : 'Top 5 Profit-Engine Products',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.slate900),
                    ),
                    const SizedBox(height: 10),
                    _buildTopProductsList(),
                    const SizedBox(height: 24),

                    // Low Stock Urgency Reorders
                    if (_lowStockProducts.isNotEmpty) ...[
                      Text(
                        _isUrduMode ? 'فوری منگوائی جانے والی اشیاء' : 'Critical Stockout Risk Watchlist',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.roseDanger),
                      ),
                      const SizedBox(height: 10),
                      _buildLowStockList(),
                    ],
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLangButton({required String title, required bool active, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.indigoPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: active ? Colors.white : AppColors.slate700,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildAiScannerHero() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.slate900,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.indigoPrimary.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.indigoPrimary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.psychology_outlined, color: Colors.cyanAccent, size: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Autonomous Copilot Active',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  _isUrduMode
                      ? 'بز پائلٹ اے آئی آپ کے روزانہ ڈیٹا کی بنیاد پر منافع اور اسٹاک کا خودکار معائنہ کرتا ہے۔'
                      : 'Real-time algorithmic checks continuously detect stockouts, margin leakages & cashflow bottlenecks.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(AiInsight insight) {
    Color cardBorder;
    Color iconBg;
    Color iconColor;
    IconData icon;

    switch (insight.severity.toLowerCase()) {
      case 'critical':
        cardBorder = AppColors.roseDanger;
        iconBg = AppColors.roseSubtle;
        iconColor = AppColors.roseDanger;
        icon = Icons.warning_rounded;
        break;
      case 'warning':
        cardBorder = AppColors.amberWarning;
        iconBg = AppColors.amberSubtle;
        iconColor = AppColors.amberWarning;
        icon = Icons.info_outline;
        break;
      case 'positive':
        cardBorder = AppColors.emeraldSuccess;
        iconBg = AppColors.emeraldSubtle;
        iconColor = AppColors.emeraldSuccess;
        icon = Icons.trending_up;
        break;
      default:
        cardBorder = AppColors.indigoPrimary;
        iconBg = AppColors.indigoSubtle;
        iconColor = AppColors.indigoPrimary;
        icon = Icons.lightbulb_outline;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: iconBg,
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        insight.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.slate900),
                      ),
                    ),
                    if (insight.metricLabel != null && insight.metricValue != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${insight.metricLabel}: ${insight.metricValue!.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: iconColor),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _isUrduMode ? insight.urduTranslation : insight.description,
                  style: const TextStyle(fontSize: 13, color: AppColors.slate700, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsList() {
    if (_topProducts.isEmpty) {
      return const Text('No products available for margin analysis.', style: TextStyle(color: AppColors.slate500));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _topProducts.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, idx) {
          final p = _topProducts[idx];
          return ListTile(
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.indigoSubtle,
              child: Text(
                '${idx + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.indigoPrimary),
              ),
            ),
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('Category: ${p.categoryName} • Cost: $_currency ${p.costPrice.toStringAsFixed(0)}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$_currency ${p.sellingPrice.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  '+${p.profitMargin.toStringAsFixed(0)}% Margin',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.emeraldSuccess),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLowStockList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.roseDanger.withValues(alpha: 0.3)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _lowStockProducts.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, idx) {
          final p = _lowStockProducts[idx];
          final isOut = p.isOutOfStock;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isOut ? AppColors.roseSubtle : AppColors.amberSubtle,
              child: Icon(
                isOut ? Icons.error_outline : Icons.warning_amber_rounded,
                color: isOut ? AppColors.roseDanger : AppColors.amberWarning,
                size: 20,
              ),
            ),
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('Remaining: ${p.stockQuantity} • Min Threshold: ${p.lowStockThreshold}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isOut ? AppColors.roseSubtle : AppColors.amberSubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isOut ? 'Order Now' : 'Reorder Soon',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isOut ? AppColors.roseDanger : AppColors.amberWarning,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
