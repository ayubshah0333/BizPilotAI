import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/sale.dart';
import '../models/customer.dart';

class WhatsAppService {
  /// Clean phone number for WhatsApp wa.me links
  static String cleanPhoneNumber(String rawPhone) {
    String cleaned = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.startsWith('03')) {
      // Pakistani local format 03XXXXXXXXX -> 923XXXXXXXXX
      cleaned = '92${cleaned.substring(1)}';
    } else if (cleaned.startsWith('+')) {
      cleaned = cleaned.substring(1);
    }
    return cleaned;
  }

  /// Generates a cleanly formatted invoice message
  static String formatInvoiceText({
    required Sale sale,
    required String businessName,
    required String currency,
  }) {
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(sale.createdAt);
    final buffer = StringBuffer();

    buffer.writeln('🧾 *$businessName — Sales Receipt*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Invoice #: *${sale.invoiceNumber}*');
    buffer.writeln('Date: $dateStr');
    buffer.writeln('Customer: *${sale.customerName}*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('ITEMS:');

    for (final item in sale.items) {
      final lineTotal = item.unitPrice * item.quantity;
      buffer.writeln('• ${item.productName} (x${item.quantity}) — $currency ${lineTotal.toStringAsFixed(2)}');
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Subtotal: $currency ${sale.totalAmount.toStringAsFixed(2)}');
    if (sale.discountAmount > 0) {
      buffer.writeln('Discount: -$currency ${sale.discountAmount.toStringAsFixed(2)}');
    }
    if (sale.taxAmount > 0) {
      buffer.writeln('Tax: +$currency ${sale.taxAmount.toStringAsFixed(2)}');
    }
    buffer.writeln('*NET TOTAL: $currency ${sale.netAmount.toStringAsFixed(2)}*');
    buffer.writeln('Payment Method: *${sale.paymentMethod}*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Thank you for your business! 🙏');
    buffer.writeln('_Powered by BizPilot AI_');

    return buffer.toString();
  }

  /// Generates a polite Urdu & English Udhaar reminder
  static String formatUdhaarReminderText({
    required Customer customer,
    required String businessName,
    required String currency,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('محترم *${customer.name}* صاحب،');
    buffer.writeln('امید ہے آپ خیریت سے ہوں گے۔');
    buffer.writeln('*$businessName* کے کھاتے کے مطابق آپ کا واجب الادا بقایا جات:');
    buffer.writeln('*$currency ${customer.currentBalance.toStringAsFixed(2)}* ہے-');
    buffer.writeln('برائے مہربانی سہولت کے مطابق ادائیگی کر دیجیے۔ شکریہ!');
    buffer.writeln('────────────────────');
    buffer.writeln('Dear *${customer.name}*,');
    buffer.writeln('This is a friendly reminder that your outstanding balance with *$businessName* is *$currency ${customer.currentBalance.toStringAsFixed(2)}*.');
    buffer.writeln('Kindly clear the balance at your earliest convenience. Thank you!');

    return buffer.toString();
  }

  /// Launches WhatsApp with the given phone and message text
  static Future<bool> launchWhatsApp({
    String? phone,
    required String message,
  }) async {
    final encodedMessage = Uri.encodeComponent(message);
    Uri uri;

    if (phone != null && phone.trim().isNotEmpty) {
      final cleanPhone = cleanPhoneNumber(phone);
      uri = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMessage');
    } else {
      uri = Uri.parse('https://wa.me/?text=$encodedMessage');
    }

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to web link
        return await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      return false;
    }
  }
}
