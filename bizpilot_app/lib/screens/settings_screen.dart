import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../theme/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _businessNameController = TextEditingController();
  final _apiUrlController = TextEditingController();
  final _taxRateController = TextEditingController();

  String _currency = 'PKR';
  bool _offlineMode = false;
  bool _isLoading = true;
  String? _connectionStatus;

  final List<String> _currencies = ['PKR', 'USD', 'INR', 'EUR', 'AED', 'SAR'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _apiUrlController.dispose();
    _taxRateController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    final bName = await ApiService.instance.getBusinessName();
    final url = await ApiService.instance.getBaseUrl();
    final curr = await ApiService.instance.getCurrency();
    final tax = await ApiService.instance.getTaxRate();
    final offline = await ApiService.instance.isOfflineMode();

    if (mounted) {
      setState(() {
        _businessNameController.text = bName;
        _apiUrlController.text = url;
        _currency = _currencies.contains(curr) ? curr : 'PKR';
        _taxRateController.text = tax.toStringAsFixed(1);
        _offlineMode = offline;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    await ApiService.instance.setBusinessName(_businessNameController.text.trim());
    await ApiService.instance.setBaseUrl(_apiUrlController.text.trim());
    await ApiService.instance.setCurrency(_currency);
    await ApiService.instance.setTaxRate(double.tryParse(_taxRateController.text.trim()) ?? 0.0);
    await ApiService.instance.setOfflineMode(_offlineMode);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuration saved successfully!'),
          backgroundColor: AppColors.emeraldSuccess,
        ),
      );
    }
  }

  Future<void> _testApiConnection() async {
    setState(() {
      _connectionStatus = 'Testing connectivity...';
    });

    try {
      final url = _apiUrlController.text.trim();
      final uri = Uri.parse('$url/dashboard.php');
      final res = await http.get(uri).timeout(const Duration(seconds: 3));

      if (mounted) {
        setState(() {
          if (res.statusCode == 200) {
            _connectionStatus = 'Connected successfully! (Status 200 OK)';
          } else {
            _connectionStatus = 'Server reached with HTTP ${res.statusCode}';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectionStatus = 'Host unreachable: $e (App will use SQLite local database)';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            'assets/images/app_logo.png',
                            width: 76,
                            height: 76,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'BizPilot AI',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slate900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Autonomous Smart Business Manager & POS',
                          style: TextStyle(fontSize: 12, color: AppColors.slate500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Store Profile Section
                  _buildSectionHeader('Store & Business Profile', Icons.storefront_outlined),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _businessNameController,
                          decoration: const InputDecoration(
                            labelText: 'Business / Shop Name',
                            prefixIcon: Icon(Icons.store),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _currency,
                                decoration: const InputDecoration(labelText: 'Store Currency'),
                                items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _currency = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _taxRateController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Default Tax (%)',
                                  prefixIcon: Icon(Icons.percent),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Offline & Network Mode Section
                  _buildSectionHeader('Offline & Connectivity Mode', Icons.cloud_sync_outlined),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Force Offline Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text(
                            'Operate entirely using the high-speed local SQLite database without remote network calls.',
                            style: TextStyle(fontSize: 12, color: AppColors.slate600),
                          ),
                          value: _offlineMode,
                          activeThumbColor: AppColors.indigoPrimary,
                          onChanged: (val) {
                            setState(() => _offlineMode = val);
                          },
                        ),
                        const Divider(height: 24),
                        TextField(
                          controller: _apiUrlController,
                          enabled: !_offlineMode,
                          decoration: const InputDecoration(
                            labelText: 'Backend REST API Endpoint',
                            hintText: 'http://localhost/BizPilotAI/backend/api',
                            prefixIcon: Icon(Icons.lan_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.slate800,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                              onPressed: _offlineMode ? null : _testApiConnection,
                              icon: const Icon(Icons.network_check, size: 16),
                              label: const Text('Test Connection', style: TextStyle(fontSize: 13)),
                            ),
                          ],
                        ),
                        if (_connectionStatus != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.slate100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _connectionStatus!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _connectionStatus!.contains('success') ? AppColors.emeraldSuccess : AppColors.amberWarning,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Diagnostics & App Info
                  _buildSectionHeader('Database & System Info', Icons.info_outline),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: const Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Storage Engine', style: TextStyle(color: AppColors.slate600)),
                            Text('SQLite Offline-First (sqflite)', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('App Version', style: TextStyle(color: AppColors.slate600)),
                            Text('BizPilot AI v1.0.0 Pro', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('WhatsApp Commerce', style: TextStyle(color: AppColors.slate600)),
                            Text('Deep-link Enabled', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.emeraldSuccess)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save Settings CTA Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      child: const Text('Save Configuration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.indigoPrimary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.slate900),
        ),
      ],
    );
  }
}
