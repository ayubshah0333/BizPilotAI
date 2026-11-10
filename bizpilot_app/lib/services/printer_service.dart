import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/sale.dart';

class PrinterService {
  static final PrinterService instance = PrinterService._init();
  PrinterService._init();

  /// Prints a 58mm or 80mm ESC/POS styled thermal receipt
  static Future<void> printThermalReceipt({
    required BuildContext context,
    required Sale sale,
    required String businessName,
    required String currency,
    bool is80mm = false,
  }) async {
    try {
      final doc = await generateThermalReceiptDoc(
        sale: sale,
        businessName: businessName,
        currency: currency,
        is80mm: is80mm,
      );

      await Printing.layoutPdf(
        name: '${sale.invoiceNumber}_receipt',
        onLayout: (PdfPageFormat format) async => doc.save(),
      );
    } catch (e) {
      debugPrint('Error printing receipt: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to print receipt: $e')),
        );
      }
    }
  }

  /// Generates the PDF document for 58mm / 80mm roll paper
  static Future<pw.Document> generateThermalReceiptDoc({
    required Sale sale,
    required String businessName,
    required String currency,
    bool is80mm = false,
  }) async {
    final pdf = pw.Document();
    final pageFormat = is80mm ? PdfPageFormat.roll80 : PdfPageFormat.roll57;
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(sale.createdAt);

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Store Header
              pw.Text(
                businessName,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'POS SALES RECEIPT',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),

              // Invoice Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Invoice:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(sale.invoiceNumber, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Date:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(dateStr, style: const pw.TextStyle(fontSize: 7.5)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Customer:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(sale.customerName, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Payment:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(sale.paymentMethod, style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),

              // Table Header
              pw.Row(
                children: [
                  pw.Expanded(flex: 5, child: pw.Text('Item', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 3, child: pw.Text('Price', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 3, child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                ],
              ),
              pw.Divider(thickness: 0.5),

              // Line Items
              ...sale.items.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 5, child: pw.Text(item.productName, style: const pw.TextStyle(fontSize: 7.5))),
                      pw.Expanded(flex: 2, child: pw.Text('${item.quantity}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7.5))),
                      pw.Expanded(flex: 3, child: pw.Text(item.unitPrice.toStringAsFixed(0), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7.5))),
                      pw.Expanded(flex: 3, child: pw.Text(item.subtotal.toStringAsFixed(0), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7.5))),
                    ],
                  ),
                );
              }),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('$currency ${sale.totalAmount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              if (sale.discountAmount > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Discount:', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('-$currency ${sale.discountAmount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              pw.SizedBox(height: 3),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL DUE:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text('$currency ${sale.netAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),

              // Footer Note & QR Code
              pw.SizedBox(height: 4),
              pw.BarcodeWidget(
                data: sale.invoiceNumber,
                barcode: pw.Barcode.qrCode(),
                width: 48,
                height: 48,
              ),
              pw.SizedBox(height: 4),
              pw.Text('Thank you for your business!', style: pw.TextStyle(fontSize: 7.5, fontStyle: pw.FontStyle.italic)),
              pw.Text('Powered by BizPilot AI', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
            ],
          );
        },
      ),
    );

    return pdf;
  }
}
