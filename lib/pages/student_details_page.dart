import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/student_model.dart';
import '../models/payment_model.dart';
import '../services/payment_service.dart';
import 'payment_confirmation_dialog.dart';
import 'receipt_screen.dart';

/// STUDENT DETAILS PAGE
/// Shows full student details with payment history
/// Replaces the numpad view with payment history
class StudentDetailsPage extends StatefulWidget {
  final Student student;

  const StudentDetailsPage({Key? key, required this.student}) : super(key: key);

  @override
  State<StudentDetailsPage> createState() => _StudentDetailsPageState();
}

class _StudentDetailsPageState extends State<StudentDetailsPage> {
  late Student _currentStudent;
  List<Payment> _paymentHistory = [];
  bool _isLoadingHistory = true;
  Payment? _studentFeePayment;
  Payment? _studentFinesPayment;

  @override
  void initState() {
    super.initState();
    _currentStudent = widget.student;
    _loadPaymentHistory();
  }

  /// LOAD PAYMENT HISTORY
  Future<void> _loadPaymentHistory() async {
    try {
      final payments = await PaymentService.getStudentPayments(
        _currentStudent.id,
      );
      if (mounted) {
        setState(() {
          _paymentHistory = payments;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load payment history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// PROCEED TO PAYMENT
  Future<void> _proceedPayment(String paymentType) async {
    final amount = paymentType == 'Fee'
        ? _currentStudent.outstandingFee
        : _currentStudent.outstandingFines;

    // Check if amount is zero
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No outstanding $paymentType to pay'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if already paid
    final existingPayment = paymentType == 'Fee'
        ? _studentFeePayment
        : _studentFinesPayment;

    if (existingPayment != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$paymentType already paid (OR: ${existingPayment.receiptNumber})',
          ),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentConfirmationDialog(
        student: _currentStudent,
        paymentType: paymentType,
        amount: amount,
      ),
    );

    if (confirmed != true) return;

    // Process payment
    try {
      final payment = await PaymentService.processPayment(
        student: _currentStudent,
        paymentType: paymentType,
        amount: amount,
        yearLevel: _currentStudent.yearLevel ?? '1st Year',
      );

      // Update state
      setState(() {
        if (paymentType == 'Fee') {
          _studentFeePayment = payment;
          _currentStudent = Student(
            id: _currentStudent.id,
            lastName: _currentStudent.lastName,
            firstName: _currentStudent.firstName,
            college: _currentStudent.college,
            program: _currentStudent.program,
            yearLevel: _currentStudent.yearLevel,
            outstandingFee: 0.0,
            outstandingFines: _currentStudent.outstandingFines,
            outstandingUnpaidBalance: _currentStudent.outstandingUnpaidBalance,
          );
        } else {
          _studentFinesPayment = payment;
          _currentStudent = Student(
            id: _currentStudent.id,
            lastName: _currentStudent.lastName,
            firstName: _currentStudent.firstName,
            college: _currentStudent.college,
            program: _currentStudent.program,
            yearLevel: _currentStudent.yearLevel,
            outstandingFee: _currentStudent.outstandingFee,
            outstandingFines: 0.0,
            outstandingUnpaidBalance: _currentStudent.outstandingUnpaidBalance,
          );
        }
      });

      // Reload payment history
      _loadPaymentHistory();

      // Navigate to receipt screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ReceiptScreen(payment: payment, student: _currentStudent),
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment successful! OR: ${payment.receiptNumber}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.school, color: Color(0xFF1B5E20)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  supabase
                          .auth
                          .currentUser
                          ?.userMetadata?['organization_name'] ??
                      'Organization',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  supabase.auth.currentUser?.email ?? '',
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // STUDENT INFORMATION CARD
            _buildStudentInfoCard(),

            const SizedBox(height: 16),

            // OUTSTANDING AMOUNTS
            _buildOutstandingAmounts(),

            const SizedBox(height: 16),

            // PAYMENT BUTTONS
            _buildPaymentButtons(),

            const SizedBox(height: 24),

            // PAYMENT HISTORY SECTION
            _buildPaymentHistorySection(),
          ],
        ),
      ),
    );
  }

  /// BUILD STUDENT INFO CARD
  Widget _buildStudentInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student ID and Year Level
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Student ID Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _currentStudent.id,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Year Level Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _currentStudent.yearLevel ?? 'N/A',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Name
          Text(
            _currentStudent.lastName.toUpperCase(),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          Text(
            _currentStudent.firstName.toUpperCase(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 8),

          // College and Program
          Text(
            '${_currentStudent.college ?? 'N/A'} - ${_currentStudent.program ?? 'N/A'}',
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.blue[700],
            ),
          ),

          const SizedBox(height: 4),

          // Student Number
          Text(
            'NO. ${_currentStudent.id}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  /// BUILD OUTSTANDING AMOUNTS
  Widget _buildOutstandingAmounts() {
    return Row(
      children: [
        // College Fee Amount
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'College Fee Amount',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '₱ ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _currentStudent.outstandingFee.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 12),

        // College Fine Amount
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'College Fine Amount',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '₱ ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _currentStudent.outstandingFines.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// BUILD PAYMENT BUTTONS
  Widget _buildPaymentButtons() {
    return Row(
      children: [
        // Fee Payment Button
        Expanded(
          child: ElevatedButton(
            onPressed: _currentStudent.outstandingFee <= 0
                ? null
                : () => _proceedPayment('Fee'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              disabledBackgroundColor: Colors.grey[300],
            ),
            child: const Text(
              'Proceed Fee\nPayment',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Fines Payment Button
        Expanded(
          child: ElevatedButton(
            onPressed: _currentStudent.outstandingFines <= 0
                ? null
                : () => _proceedPayment('Fines'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              disabledBackgroundColor: Colors.grey[300],
            ),
            child: const Text(
              'Proceed Fines\nPayment',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  /// BUILD PAYMENT HISTORY SECTION
  Widget _buildPaymentHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PAYMENT HISTORY',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
            letterSpacing: 1,
          ),
        ),

        const SizedBox(height: 12),

        // Payment History List
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _isLoadingHistory
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _paymentHistory.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No payment history',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _paymentHistory.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.grey[200]),
                  itemBuilder: (context, index) {
                    final payment = _paymentHistory[index];
                    return _buildPaymentHistoryItem(payment);
                  },
                ),
        ),
      ],
    );
  }

  /// BUILD PAYMENT HISTORY ITEM
  Widget _buildPaymentHistoryItem(Payment payment) {
    final dateFormat = DateFormat('MM-dd-yyyy');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Left side - Payment info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateFormat.format(payment.paymentDate),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  payment.paymentType == 'Fee'
                      ? 'College Fee'
                      : 'College Fines',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Receipt NO. ${payment.receiptNumber}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // Right side - Amount
          Text(
            '₱ ${payment.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
        ],
      ),
    );
  }
}
