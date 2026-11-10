import 'package:flutter_test/flutter_test.dart';
import 'package:bizpilot_app/models/product.dart';
import 'package:bizpilot_app/models/customer.dart';
import 'package:bizpilot_app/models/sale.dart';
import 'package:bizpilot_app/models/sale_item.dart';
import 'package:bizpilot_app/models/ai_insight.dart';
import 'package:bizpilot_app/services/whatsapp_service.dart';

void main() {
  group('BizPilot AI Models Test Suite', () {
    test('Product stock calculations & margins', () {
      const prod = Product(
        id: 1,
        name: 'Super Basmati Rice 5kg',
        sku: 'RCE-001',
        barcode: '8961014101',
        costPrice: 1400.0,
        sellingPrice: 1750.0,
        stockQuantity: 3,
        lowStockThreshold: 5,
      );

      expect(prod.unitProfit, 350.0);
      expect(prod.profitMargin, closeTo(20.0, 0.1));
      expect(prod.isLowStock, isTrue);
      expect(prod.isOutOfStock, isFalse);
    });

    test('Customer Udhaar balance & credit limit checks', () {
      const cust = Customer(
        id: 1,
        name: 'Kamran Traders',
        phone: '03219876543',
        creditLimit: 50000.0,
        currentBalance: 28000.0,
      );

      expect(cust.hasOutstandingUdhaar, isTrue);
      expect(cust.isOverLimit, isFalse);

      final overCust = cust.copyWith(currentBalance: 55000.0);
      expect(overCust.isOverLimit, isTrue);
    });

    test('Sale profit calculation with items', () {
      final sale = Sale(
        invoiceNumber: 'INV-TEST-001',
        customerName: 'Test Buyer',
        totalAmount: 1000.0,
        discountAmount: 50.0,
        netAmount: 950.0,
        paymentMethod: 'Cash',
        items: const [
          SaleItem(
            productId: 1,
            productName: 'Item A',
            unitPrice: 100.0,
            costPrice: 80.0,
            quantity: 10,
            subtotal: 1000.0,
          ),
        ],
        createdAt: DateTime.now(),
      );

      expect(sale.calculatedTotalProfit, 150.0);
    });

    test('AiInsight JSON serialization & severity', () {
      final now = DateTime.now();
      final insight = AiInsight(
        id: 'ins-test',
        title: 'Sales Spike',
        type: 'trend',
        description: 'Revenue spiked 25%',
        urduTranslation: 'آمدنی میں 25 فیصد اضافہ ہوا',
        severity: 'positive',
        metricValue: 25.0,
        metricLabel: 'Growth',
        createdAt: now,
      );

      final json = insight.toJson();
      expect(json['id'], 'ins-test');
      expect(json['severity'], 'positive');

      final fromJson = AiInsight.fromJson(json);
      expect(fromJson.title, 'Sales Spike');
      expect(fromJson.metricValue, 25.0);
    });
  });

  group('WhatsApp Service Formatting', () {
    test('formatInvoiceText produces valid receipt with items', () {
      final sale = Sale(
        invoiceNumber: 'INV-9999',
        customerName: 'Haji Tariq',
        totalAmount: 570.0,
        discountAmount: 20.0,
        netAmount: 550.0,
        paymentMethod: 'Cash',
        items: const [
          SaleItem(
            productId: 1,
            productName: 'Surf Excel',
            unitPrice: 570.0,
            costPrice: 480.0,
            quantity: 1,
            subtotal: 570.0,
          ),
        ],
        createdAt: DateTime(2026, 11, 10, 14, 30),
      );

      final invoice = WhatsAppService.formatInvoiceText(
        sale: sale,
        businessName: 'Al-Madina Store',
        currency: 'PKR',
      );

      expect(invoice.contains('Al-Madina Store'), isTrue);
      expect(invoice.contains('INV-9999'), isTrue);
      expect(invoice.contains('Haji Tariq'), isTrue);
      expect(invoice.contains('Surf Excel'), isTrue);
      expect(invoice.contains('NET TOTAL: PKR 550.00'), isTrue);
    });

    test('formatUdhaarReminderText includes bilingual message', () {
      const customer = Customer(
        id: 2,
        name: 'Kamran Traders',
        phone: '03219876543',
        currentBalance: 12500.0,
      );

      final reminder = WhatsAppService.formatUdhaarReminderText(
        customer: customer,
        businessName: 'Al-Madina Store',
        currency: 'PKR',
      );

      expect(reminder.contains('Kamran Traders'), isTrue);
      expect(reminder.contains('12500.00'), isTrue);
      expect(reminder.contains('Al-Madina Store'), isTrue);
      expect(reminder.contains('واجب الادا بقایا جات'), isTrue);
      expect(reminder.contains('outstanding balance'), isTrue);
    });

    test('cleanPhoneNumber formats Pakistani mobile numbers', () {
      expect(WhatsAppService.cleanPhoneNumber('03001234567'), '923001234567');
      expect(WhatsAppService.cleanPhoneNumber('+923219876543'), '923219876543');
    });
  });
}
