import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/customer.dart';
import '../services/api_service.dart';
import '../services/whatsapp_service.dart';
import '../theme/theme.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Customer> _customers = [];
  bool _isLoading = true;
  String _currency = 'PKR';
  String _businessName = 'BizPilot Store';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);

    final curr = await ApiService.instance.getCurrency();
    final bName = await ApiService.instance.getBusinessName();
    final custs = await ApiService.instance.fetchCustomers(query: _searchController.text.trim());

    if (mounted) {
      setState(() {
        _currency = curr;
        _businessName = bName;
        _customers = custs;
        _isLoading = false;
      });
    }
  }

  String _formatAmount(double amount) {
    return '$_currency ${NumberFormat('#,##0.00').format(amount)}';
  }

  double get _totalOutstandingUdhaar {
    return _customers.fold(0.0, (acc, c) => acc + c.currentBalance);
  }

  void _showAddCustomerDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final limitController = TextEditingController(text: '25000');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Khata Customer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Customer Name *', hintText: 'e.g. Tariq Mehmood'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'WhatsApp / Phone *', hintText: '03001234567'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Shop / Address', hintText: 'Main Bazaar'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: limitController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Credit Limit ($_currency)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter name and phone number!')),
                );
                return;
              }

              final newCust = Customer(
                id: 0,
                name: nameController.text.trim(),
                phone: phoneController.text.trim(),
                address: addressController.text.trim(),
                creditLimit: double.tryParse(limitController.text.trim()) ?? 0.0,
                currentBalance: 0.0,
              );

              Navigator.pop(ctx);
              await ApiService.instance.saveCustomer(newCust);
              _loadCustomers();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Customer registered successfully!'),
                    backgroundColor: AppColors.emeraldSuccess,
                  ),
                );
              }
            },
            child: const Text('Save Customer'),
          ),
        ],
      ),
    );
  }

  void _openLedgerModal(Customer customer) async {
    final entries = await ApiService.instance.fetchCustomerUdhaarHistory(customer.id);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Text(
                            customer.phone,
                            style: const TextStyle(color: AppColors.slate500, fontSize: 13),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Total Due Hero Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: customer.currentBalance > 0 ? AppColors.roseSubtle : AppColors.emeraldSubtle,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: customer.currentBalance > 0 ? AppColors.roseDanger.withValues(alpha: 0.3) : AppColors.emeraldSuccess.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Current Outstanding Udhaar',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.slate700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatAmount(customer.currentBalance),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: customer.currentBalance > 0 ? AppColors.roseDanger : AppColors.emeraldSuccess,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                        if (customer.currentBalance > 0)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.emeraldSuccess,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            icon: const Icon(Icons.share, size: 16),
                            label: const Text('Reminder', style: TextStyle(fontSize: 13)),
                            onPressed: () {
                              final text = WhatsAppService.formatUdhaarReminderText(
                                customer: customer,
                                businessName: _businessName,
                                currency: _currency,
                              );
                              WhatsAppService.launchWhatsApp(
                                phone: customer.phone,
                                message: text,
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons (Receive Payment & Give Credit)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.arrow_upward_rounded, color: AppColors.roseDanger, size: 18),
                          label: const Text('Add Udhaar (+)', style: TextStyle(color: AppColors.roseDanger)),
                          onPressed: () {
                            _showTransactionDialog(
                              customer: customer,
                              type: 'credit',
                              onSuccess: () {
                                Navigator.pop(ctx);
                                _loadCustomers();
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldSuccess),
                          icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                          label: const Text('Got Payment (-)'),
                          onPressed: () {
                            _showTransactionDialog(
                              customer: customer,
                              type: 'payment',
                              onSuccess: () {
                                Navigator.pop(ctx);
                                _loadCustomers();
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Ledger History',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900),
                  ),
                  const SizedBox(height: 8),

                  Expanded(
                    child: entries.isEmpty
                        ? const Center(
                            child: Text('No previous transactions for this customer.', style: TextStyle(color: AppColors.slate500)),
                          )
                        : ListView.separated(
                            itemCount: entries.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final e = entries[idx];
                              final isCredit = e.isCredit;
                              final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(e.createdAt);

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: isCredit ? AppColors.roseSubtle : AppColors.emeraldSubtle,
                                  child: Icon(
                                    isCredit ? Icons.arrow_outward_rounded : Icons.south_west_rounded,
                                    color: isCredit ? AppColors.roseDanger : AppColors.emeraldSuccess,
                                    size: 18,
                                  ),
                                ),
                                title: Text(
                                  isCredit ? 'Udhaar Added' : 'Payment Received',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                subtitle: Text(
                                  e.notes.isNotEmpty ? '${e.notes} • $dateStr' : dateStr,
                                  style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                                ),
                                trailing: Text(
                                  '${isCredit ? '+' : '-'} ${_formatAmount(e.amount)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: isCredit ? AppColors.roseDanger : AppColors.emeraldSuccess,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              );
                            },
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

  void _showTransactionDialog({
    required Customer customer,
    required String type, // 'credit' or 'payment'
    required VoidCallback onSuccess,
  }) {
    final isCredit = type == 'credit';
    final amountController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isCredit ? 'Record Credit (Udhaar Diya)' : 'Record Payment (Raqam Wusool)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${customer.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Amount ($_currency) *',
                prefixIcon: const Icon(Icons.attach_money),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes / Description',
                hintText: 'e.g. Paid cash at shop counter',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isCredit ? AppColors.roseDanger : AppColors.emeraldSuccess,
            ),
            onPressed: () async {
              final amt = double.tryParse(amountController.text.trim()) ?? 0.0;
              if (amt <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount!')),
                );
                return;
              }

              Navigator.pop(ctx);
              await ApiService.instance.addUdhaarTransaction(
                customerId: customer.id,
                customerName: customer.name,
                type: type,
                amount: amt,
                notes: notesController.text.trim(),
              );

              onSuccess();
            },
            child: Text(isCredit ? 'Add to Khata' : 'Record Received'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Udhaar / Khata', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadCustomers,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.indigoPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Customer', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showAddCustomerDialog,
      ),
      body: Column(
        children: [
          // Receivables Header Banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.slate900,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Udhaar Receivables',
                      style: TextStyle(color: AppColors.slate300, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatAmount(_totalOutstandingUdhaar),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.roseDanger.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.roseDanger.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '${_customers.where((c) => c.hasOutstandingUdhaar).length} Pending',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _loadCustomers(),
              decoration: InputDecoration(
                hintText: 'Search customer by name or phone...',
                prefixIcon: const Icon(Icons.search, color: AppColors.slate400),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _loadCustomers();
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Customer list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _customers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.people_outline, size: 48, color: AppColors.slate400),
                            const SizedBox(height: 12),
                            const Text('No customers found.', style: TextStyle(color: AppColors.slate500)),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _showAddCustomerDialog,
                              child: const Text('Add Customer'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadCustomers,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _customers.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final c = _customers[index];
                            final hasDue = c.hasOutstandingUdhaar;

                            return InkWell(
                              onTap: () => _openLedgerModal(c),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.slate200),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: hasDue ? AppColors.roseSubtle : AppColors.indigoSubtle,
                                      child: Text(
                                        c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: hasDue ? AppColors.roseDanger : AppColors.indigoPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            c.phone,
                                            style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                                          ),
                                          if (c.creditLimit > 0)
                                            Text(
                                              'Limit: ${_formatAmount(c.creditLimit)}',
                                              style: const TextStyle(fontSize: 11, color: AppColors.slate400),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          hasDue ? 'Udhaar Due' : 'Cleared',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: hasDue ? AppColors.roseDanger : AppColors.emeraldSuccess,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatAmount(c.currentBalance),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                            color: hasDue ? AppColors.roseDanger : AppColors.slate800,
                                            fontFeatures: const [FontFeature.tabularFigures()],
                                          ),
                                        ),
                                        if (hasDue)
                                          InkWell(
                                            onTap: () {
                                              final text = WhatsAppService.formatUdhaarReminderText(
                                                customer: c,
                                                businessName: _businessName,
                                                currency: _currency,
                                              );
                                              WhatsAppService.launchWhatsApp(
                                                phone: c.phone,
                                                message: text,
                                              );
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.only(top: 4),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.share, size: 12, color: AppColors.emeraldSuccess),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Reminder',
                                                    style: TextStyle(fontSize: 11, color: AppColors.emeraldSuccess, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
