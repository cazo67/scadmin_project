import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/payment_model.dart';
import '../models/student_model.dart';

/// RECEIPT SCREEN
/// Displays payment receipt with Print and Download options
class ReceiptScreen extends StatelessWidget {
  final Payment payment;
  final Student student;

  const ReceiptScreen({Key? key, required this.payment, required this.student})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Payment Receipt',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1B5E20),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                // RECEIPT PREVIEW
                _buildReceiptPreview(context),

                const SizedBox(height: 24),

                // ACTION BUTTONS
                Row(
                  children: [
                    // PRINT BUTTON (Yellow)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _printReceipt(),
                        icon: const Icon(Icons.print),
                        label: const Text('Print Receipt'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFC107),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // DOWNLOAD BUTTON (Green)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _downloadReceipt(),
                        icon: const Icon(Icons.download),
                        label: const Text('Download Receipt'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B5E20),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // CLOSE BUTTON
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// BUILD RECEIPT PREVIEW
  /// Shows on-screen preview of the receipt
  Widget _buildReceiptPreview(BuildContext context) {
    final dateFormat = DateFormat('MM-dd-yyyy');
    final amountInWords = _numberToWords(payment.amount);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          const Center(
            child: Column(
              children: [
                Text(
                  'Central Mindanao University',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'College of Information Sciences & Computing',
                  style: TextStyle(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Student Council Organization (CSCO)',
                  style: TextStyle(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'University Town, Musuan, Maramag, Bukidnon',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
                Text(
                  'A.Y. 2025-2026 - 2nd Semester',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(),

          // RECEIPT INFO
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'OFFICIAL RECEIPT',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'NO. ${payment.receiptNumber}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text('Date: ${dateFormat.format(payment.paymentDate)}'),

          const SizedBox(height: 12),

          const Text('RECEIVED from'),
          Text(
            payment.studentName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),

          const SizedBox(height: 8),

          Text('Amount of (Php $amountInWords) in payment of:'),

          const SizedBox(height: 16),

          // TABLE
          Table(
            border: TableBorder.all(color: Colors.black),
            children: [
              // Header row
              const TableRow(
                children: [
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Particulars',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Amount',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              // Data row
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('College ${payment.paymentType}'),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(payment.amount.toStringAsFixed(2)),
                  ),
                ],
              ),
              // Total row
              TableRow(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Total:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      payment.amount.toStringAsFixed(2),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // STATUS
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border.all(color: Colors.black)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Status',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildStatusCheckbox('1st Year', payment.yearLevel),
                _buildStatusCheckbox('2nd Year', payment.yearLevel),
                _buildStatusCheckbox('3rd Year', payment.yearLevel),
                _buildStatusCheckbox('4th Year', payment.yearLevel),
                _buildStatusCheckbox('Extendee', payment.yearLevel),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // SIGNATURES
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(height: 1, color: Colors.black),
                    const SizedBox(height: 4),
                    const Text(
                      'Student Signature',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    Container(height: 1, color: Colors.black),
                    const SizedBox(height: 4),
                    const Text(
                      'Authorized Signature',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // NOTE
          const Center(
            child: Text(
              'Note: Valid only with stamp or\nsigned by an authorized signature.',
              style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /// BUILD STATUS CHECKBOX
  /// Shows year level checkbox (shaded if selected)
  Widget _buildStatusCheckbox(String label, String? selectedYearLevel) {
    final isSelected = label == selectedYearLevel;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black),
              color: isSelected ? Colors.grey[400] : Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  /// NUMBER TO WORDS CONVERTER
  /// Converts amount to words (e.g., 1500.50 → "One Thousand Five Hundred and 50/100")
  String _numberToWords(double amount) {
    // Simple implementation - you can enhance this
    final pesos = amount.floor();
    final centavos = ((amount - pesos) * 100).round();

    // For now, return simple format
    return '${_convertNumberToWords(pesos)} and $centavos/100';
  }

  String _convertNumberToWords(int number) {
    if (number == 0) return 'Zero';

    // Simple implementation for numbers up to thousands
    // You can expand this for larger numbers
    final ones = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
    ];
    final teens = [
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen',
    ];
    final tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety',
    ];

    if (number < 10) return ones[number];
    if (number < 20) return teens[number - 10];
    if (number < 100) {
      final ten = number ~/ 10;
      final one = number % 10;
      return '${tens[ten]}${one > 0 ? ' ${ones[one]}' : ''}';
    }
    if (number < 1000) {
      final hundred = number ~/ 100;
      final remainder = number % 100;
      return '${ones[hundred]} Hundred${remainder > 0 ? ' ${_convertNumberToWords(remainder)}' : ''}';
    }
    if (number < 10000) {
      final thousand = number ~/ 1000;
      final remainder = number % 1000;
      return '${ones[thousand]} Thousand${remainder > 0 ? ' ${_convertNumberToWords(remainder)}' : ''}';
    }

    return number.toString(); // Fallback for large numbers
  }

  /// PRINT RECEIPT
  /// Opens print dialog
  Future<void> _printReceipt() async {
    final pdf = await _generatePDF();
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  /// DOWNLOAD RECEIPT
  /// Downloads PDF file
  Future<void> _downloadReceipt() async {
    final pdf = await _generatePDF();
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'receipt_${payment.receiptNumber}.pdf',
    );
  }

  /// GENERATE PDF
  /// Creates PDF document of the receipt
  Future<pw.Document> _generatePDF() async {
    final pdf = pw.Document();

    // Format date
    final dateFormat = DateFormat('MM-dd-yyyy');
    final formattedDate = dateFormat.format(payment.paymentDate);

    // Convert amount to words
    final amountInWords = _numberToWords(payment.amount);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Central Mindanao University',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'College of Information Sciences & Computing',
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                    pw.Text(
                      'Student Council Organization (CSCO)',
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                    pw.Text(
                      'University Town, Musuan, Maramag, Bukidnon',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'A.Y. 2025-2026 - 2nd Semester',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),
              pw.Divider(),

              // RECEIPT NUMBER AND TITLE
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'OFFICIAL RECEIPT',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'NO. ${payment.receiptNumber}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 12),

              // DATE
              pw.Text('Date: $formattedDate'),

              pw.SizedBox(height: 12),

              // RECEIVED FROM
              pw.Text('RECEIVED from'),
              pw.Text(
                payment.studentName,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16,
                ),
              ),

              pw.SizedBox(height: 8),

              // AMOUNT IN WORDS
              pw.Text('Amount of (Php $amountInWords) in payment of:'),

              pw.SizedBox(height: 16),

              // TABLE
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Particulars and Amount Table
                  pw.Expanded(
                    flex: 3,
                    child: pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.black),
                      children: [
                        // Header row
                        pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8.0),
                              child: pw.Text(
                                'Particulars',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8.0),
                              child: pw.Text(
                                'Amount',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Data row
                        pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8.0),
                              child: pw.Text('College ${payment.paymentType}'),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8.0),
                              child: pw.Text(payment.amount.toStringAsFixed(2)),
                            ),
                          ],
                        ),
                        // Total row
                        pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8.0),
                              child: pw.Text(
                                'Total:',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8.0),
                              child: pw.Text(
                                payment.amount.toStringAsFixed(2),
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(width: 16),

                  // Status Section
                  pw.Expanded(
                    flex: 1,
                    child: pw.Container(
                      decoration: pw.BoxDecoration(border: pw.Border.all()),
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Status',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 8),
                          _buildPdfCheckbox('1st Year', payment.yearLevel),
                          _buildPdfCheckbox('2nd Year', payment.yearLevel),
                          _buildPdfCheckbox('3rd Year', payment.yearLevel),
                          _buildPdfCheckbox('4th Year', payment.yearLevel),
                          _buildPdfCheckbox('Extendee', payment.yearLevel),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 24),

              // SIGNATURES
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(
                        width: 150,
                        height: 1,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Student Signature'),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(
                        width: 150,
                        height: 1,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Authorized Signature'),
                    ],
                  ),
                ],
              ),

              pw.Spacer(),

              // NOTE
              pw.Center(
                child: pw.Text(
                  'Note: Valid only with stamp or\nsigned by an authorized signature.',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  /// BUILD PDF CHECKBOX
  /// Creates a checkbox widget for PDF with shading if selected
  pw.Widget _buildPdfCheckbox(String label, String? selectedYearLevel) {
    final isSelected = label == selectedYearLevel;

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Container(
            width: 12,
            height: 12,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black),
              color: isSelected ? PdfColors.grey400 : PdfColors.white,
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}
