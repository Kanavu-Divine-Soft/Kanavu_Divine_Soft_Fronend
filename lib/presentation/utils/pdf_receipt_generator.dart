import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfReceiptGenerator {
  static Future<void> generateAndSaveReceipt(Map<String, dynamic> member,
      {String? templeName, Map<String, dynamic>? selectedPayment}) async {
    final pdf = pw.Document();

    final name = member['Name']?.toString() ?? 'N/A';
    final code = member['Code']?.toString() ?? 'N/A';
    final mobile = member['Mobile_Number']?.toString() ?? 'N/A';

    // Sun Tommy encoded Tamil: language == 'Tamil' means names are stored
    // in Sun Tommy ASCII encoding, so we MUST use SunTommy.ttf in the PDF
    final bool useSunTommy = member['Language']?.toString() == 'Tamil';

    // Load SunTommy font from assets for Tamil names
    pw.Font? sunTommyFont;
    if (useSunTommy) {
      try {
        final fontData = await rootBundle.load('assets/fonts/SunTommy.ttf');
        sunTommyFont = pw.Font.ttf(fontData);
      } catch (e) {
        sunTommyFont = null;
      }
    }

    // Parse payments
    List<dynamic> payments = [];
    if (member['Payments'] != null) {
      if (member['Payments'] is String) {
        try {
          payments = jsonDecode(member['Payments']);
        } catch (_) {}
      } else if (member['Payments'] is List) {
        payments = member['Payments'];
      }
    }

    List<dynamic> paidPayments = [];
    if (selectedPayment != null) {
      paidPayments = [selectedPayment];
    } else {
      paidPayments =
          payments.where((p) => p['status']?.toString() == 'Paid').toList();
    }

    double totalAmount = 0.0;
    for (var p in paidPayments) {
      totalAmount += double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
    }

    // Build name text widget using correct font
    pw.Widget buildNameWidget() {
      if (useSunTommy && sunTommyFont != null) {
        return pw.Row(
          children: [
            pw.Text('Name: ', style: const pw.TextStyle(fontSize: 12)),
            pw.Text(
              name,
              style: pw.TextStyle(
                font: sunTommyFont,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        );
      }
      return pw.Text('Name: $name', style: const pw.TextStyle(fontSize: 12));
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Text(
                    templeName ?? 'Eswaran Kovil',
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Center(
                  child: pw.Text(
                    'Statement of Contributions',
                    style:
                        const pw.TextStyle(fontSize: 18, color: PdfColors.grey700),
                  ),
                ),
                pw.SizedBox(height: 32),

                // Member Info
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Member Details',
                            style: pw.TextStyle(
                                fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 8),
                        buildNameWidget(),
                        pw.Text('Code: $code'),
                        pw.Text('Mobile: $mobile'),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                            'Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          'Total Paid: Rs. ${totalAmount.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 32),

                // Table
                pw.Text('Payment History',
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 16),
                if (paidPayments.isEmpty)
                  pw.Center(
                      child: pw.Text('No paid contributions found.',
                          style: const pw.TextStyle(color: PdfColors.grey)))
                else
                  pw.TableHelper.fromTextArray(
                    context: context,
                    headerDecoration:
                        const pw.BoxDecoration(color: PdfColors.grey300),
                    headerHeight: 25,
                    cellHeight: 30,
                    cellAlignments: {
                      0: pw.Alignment.centerLeft,
                      1: pw.Alignment.center,
                      2: pw.Alignment.centerRight,
                    },
                    headers: ['Event Name', 'Year', 'Amount (Rs.)'],
                    data: paidPayments.map((p) {
                      return [
                        p['event_name']?.toString() ?? 'N/A',
                        p['year']?.toString() ?? 'N/A',
                        double.tryParse(p['amount']?.toString() ?? '0')
                                ?.toStringAsFixed(2) ??
                            '0.00',
                      ];
                    }).toList(),
                  ),

                pw.Spacer(),
                // Footer
                pw.Center(
                  child: pw.Text(
                    'Thank you for your generous contribution!',
                    style: pw.TextStyle(
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColors.grey600),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Receipt_$code.pdf',
    );
  }
}
