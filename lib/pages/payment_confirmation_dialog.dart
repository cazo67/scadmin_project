import 'package:flutter/material.dart';
import '../models/student_model.dart';

/// PAYMENT CONFIRMATION DIALOG
/// Shows payment details and year level selection before processing payment
class PaymentConfirmationDialog extends StatefulWidget {
  final Student student;
  final String paymentType; // "Fee" or "Fines"
  final double amount;

  const PaymentConfirmationDialog({
    Key? key,
    required this.student,
    required this.paymentType,
    required this.amount,
  }) : super(key: key);

  @override
  State<PaymentConfirmationDialog> createState() => _PaymentConfirmationDialogState();
}

class _PaymentConfirmationDialogState extends State<PaymentConfirmationDialog> {
  String? _selectedYearLevel; // User must select year level

  @override
  void initState() {
    super.initState();
    // Pre-select student's current year level from database
  
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // HEADER
            Row(
              children: [
                Icon(
                  Icons.receipt_long,
                  color: Colors.blue[700],
                  size: 32,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Confirm Payment',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            
            const Divider(height: 24),
            
            // STUDENT INFO
            _buildInfoRow('Student Name:', widget.student.fullName),
            const SizedBox(height: 8),
            _buildInfoRow('Student ID:', widget.student.id),
            const SizedBox(height: 8),
            _buildInfoRow('Payment Type:', widget.paymentType),
            const SizedBox(height: 8),
            
            // AMOUNT (highlighted)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[300]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Amount to Pay:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '₱${widget.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // YEAR LEVEL (Display Only)
            _buildInfoRow('Year Level:', widget.student.yearLevel ?? 'N/A'),
            const SizedBox(height: 8),
            _buildInfoRow('College:', widget.student.college ?? 'N/A'),
            const SizedBox(height: 8),
            _buildInfoRow('Program:', widget.student.program ?? 'N/A'),
            const SizedBox(height: 24),
            
            // CONFIRM BUTTON
          // CONFIRM BUTTON
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Confirm Payment',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // CANCEL BUTTON
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  /// BUILD INFO ROW
  /// Helper to display label and value pairs
  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}