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
    _selectedYearLevel = widget.student.yearLevel;
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
            
            // YEAR LEVEL SELECTION
            const Text(
              'Select Year Level:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            _buildYearLevelOption('1st Year'),
            _buildYearLevelOption('2nd Year'),
            _buildYearLevelOption('3rd Year'),
            _buildYearLevelOption('4th Year'),
            _buildYearLevelOption('Extendee'),
            
            const SizedBox(height: 24),
            
            // CONFIRM BUTTON
            ElevatedButton(
              onPressed: _selectedYearLevel == null 
                  ? null 
                  : () => Navigator.pop(context, _selectedYearLevel),
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

  /// BUILD YEAR LEVEL OPTION
  /// Radio button option for year level selection
  Widget _buildYearLevelOption(String yearLevel) {
    final isSelected = _selectedYearLevel == yearLevel;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedYearLevel = yearLevel;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.green[700]! : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? Colors.green[700] : Colors.grey,
            ),
            const SizedBox(width: 12),
            Text(
              yearLevel,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.green[700] : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}