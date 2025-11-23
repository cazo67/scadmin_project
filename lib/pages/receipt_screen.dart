import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../models/payment_model.dart';
import '../models/student_model.dart';

/// RECEIPT SCREEN
/// Displays payment receipt with Print and Download options
class ReceiptScreen extends StatelessWidget {
  final Payment payment;
  final Student student;

  const ReceiptScreen({
    Key? key,
    required this.payment,
    required this.student,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Receipt'),
        backgroundColor: const Color(0xFF1B5E20),
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'College of Information Sciences & Computing',
                  style: TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Student Council Organization (CSCO)',
                  style: TextStyle(fontSize: 14),
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
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
                    child: Text('Particulars', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    child: Text('Total:', style: TextStyle(fontWeight: FontWeight.bold)),
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
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
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
              Column(
                children: [
                  Container(
                    width: 150,
                    height: 1,
                    color: Colors.black,
                  ),
                  const SizedBox(height: 4),
                  const Text('Student Signature'),
                ],
              ),
              Column(
                children: [
                  Container(
                    width: 150,
                    height: 1,
                    color: Colors.black,
                  ),
                  const SizedBox(height: 4),
                  const Text('Authorized Signature'),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // QR CODE
          Center(
            child: Column(
              children: [
                QrImageView(
                  data: _generateQRData(),
                  version: QrVersions.auto,
                  size: 120,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Note: Valid only with stamp or\nsigned by an authorized signature.',
                  style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ],
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

  /// GENERATE QR CODE DATA
  /// Contains receipt verification information
  String _generateQRData() {
    return 'OR:${payment.receiptNumber}|'
           'NAME:${payment.studentName}|'
           'DATE:${DateFormat('MM-dd-yyyy').format(payment.paymentDate)}|'
           'AMOUNT:${payment.amount}|'
           'TYPE:${payment.paymentType}|'
           'YEAR:${payment.yearLevel}';
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
    final ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine'];
    final teens = ['Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    final tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
    
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
    
    // TODO: We'll implement PDF generation next
    // For now, return empty PDF
    
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Center(
          child: pw.Text('Receipt PDF - Coming in next step!'),
        ),
      ),
    );
    
    return pdf;
  }
}