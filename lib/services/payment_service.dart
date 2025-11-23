import '../main.dart';
import '../models/student_model.dart';
import '../models/payment_model.dart';

/// PAYMENT SERVICE
/// Handles all payment-related operations:
/// - Generate receipt numbers
/// - Record payments in database
/// - Update student balances
class PaymentService {
  
  /// GET NEXT RECEIPT NUMBER
  /// Fetches and increments the receipt counter from database
  /// Returns formatted 6-digit receipt number (e.g., "002031")
  static Future<String> getNextReceiptNumber() async {
    try {
      // Fetch current counter
      final response = await supabase
          .from('receipt_counter')
          .select('counter')
          .eq('id', 'receipt')
          .single();

      final currentCounter = response['counter'] as int;
      final nextCounter = currentCounter + 1;

      // Update counter in database (increment by 1)
      await supabase
          .from('receipt_counter')
          .update({'counter': nextCounter, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', 'receipt');

      // Format as 6-digit string with leading zeros
      return Payment.formatReceiptNumber(nextCounter);
      
    } catch (e) {
      throw Exception('Failed to generate receipt number: $e');
    }
  }

  /// PROCESS PAYMENT
  /// Records payment, updates student balance, returns Payment object
  static Future<Payment> processPayment({
    required Student student,
    required String paymentType, // "Fee" or "Fines"
    required double amount,
    required String yearLevel,
  }) async {
    try {
      // STEP 1: Get next receipt number
      final receiptNumber = await getNextReceiptNumber();

      // STEP 2: Create payment record
      final paymentData = {
        'receipt_number': receiptNumber,
        'student_id': student.id,
        'student_name': '${student.lastName}, ${student.firstName}',
        'payment_type': paymentType,
        'amount': amount,
        'year_level': yearLevel,
        'payment_date': DateTime.now().toIso8601String(),
      };

      // Insert into payments table
      final paymentResponse = await supabase
          .from('payments')
          .insert(paymentData)
          .select()
          .single();

      // STEP 3: Update student balance
      await _updateStudentBalance(student, paymentType, amount);

      // STEP 4: Return Payment object
      return Payment.fromJson(paymentResponse);
      
    } catch (e) {
      throw Exception('Payment processing failed: $e');
    }
  }

  /// UPDATE STUDENT BALANCE
  /// Reduces outstanding fee or fines to zero after payment
  static Future<void> _updateStudentBalance(
    Student student,
    String paymentType,
    double amount,
  ) async {
    try {
      // Determine which field to update based on payment type
      final updateData = <String, dynamic>{};
      
      if (paymentType == 'Fee') {
        // Set outstanding_fee to 0 (full payment)
        updateData['outstanding_fee'] = 0.0;
      } else if (paymentType == 'Fines') {
        // Set outstanding_fines to 0 (full payment)
        updateData['outstanding_fines'] = 0.0;
      }

      // Update student record in database
      await supabase
          .from('students')
          .update(updateData)
          .eq('id', student.id);
          
    } catch (e) {
      throw Exception('Failed to update student balance: $e');
    }
  }

  /// GET STUDENT PAYMENTS
  /// Fetches all payment history for a specific student
  static Future<List<Payment>> getStudentPayments(String studentId) async {
    try {
      final response = await supabase
          .from('payments')
          .select()
          .eq('student_id', studentId)
          .order('payment_date', ascending: false); // Newest first

      return (response as List)
          .map((json) => Payment.fromJson(json))
          .toList();
          
    } catch (e) {
      throw Exception('Failed to fetch payment history: $e');
    }
  }

  /// CHECK IF STUDENT HAS PAID
  /// Returns payment info if student has already paid for specific type
  static Future<Payment?> checkExistingPayment(
    String studentId,
    String paymentType,
  ) async {
    try {
      final response = await supabase
          .from('payments')
          .select()
          .eq('student_id', studentId)
          .eq('payment_type', paymentType)
          .maybeSingle();

      if (response == null) return null;
      
      return Payment.fromJson(response);
      
    } catch (e) {
      throw Exception('Failed to check payment status: $e');
    }
  }
}