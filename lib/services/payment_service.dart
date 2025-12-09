import '../main.dart';
import '../models/student_model.dart';
import '../models/payment_model.dart';

/// PAYMENT SERVICE
/// Handles all payment-related operations:
/// - Generate receipt numbers
/// - Record payments in database
/// - Update student balances

class PaymentService {
  /// GET CURRENT USER'S ORGANIZATION ID
  /// Fetches organization_id from user metadata
  static String _getCurrentOrganizationId() {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    final orgId = user.userMetadata?['organization_id'];
    if (orgId == null) {
      throw Exception('User has no organization_id');
    }

    return orgId.toString();
  }

  /// GET NEXT RECEIPT NUMBER
  /// Fetches and increments the receipt counter from database
  /// Returns formatted 6-digit receipt number (e.g., "002031")
  static Future<String> getNextReceiptNumber() async {
    try {
      final orgId = _getCurrentOrganizationId(); // Get current org ID

      // Fetch current counter for THIS organization
      final response = await supabase
          .from('receipt_counter')
          .select('counter')
          .eq('id', 'receipt')
          .eq('organization_id', orgId) // Filter by organization
          .single();

      final currentCounter = response['counter'] as int;
      final nextCounter = currentCounter + 1;

      // Update counter in database (increment by 1)
      await supabase
          .from('receipt_counter')
          .update({
            'counter': nextCounter,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', 'receipt')
          .eq('organization_id', orgId); // Update only THIS organization

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
      final orgId = _getCurrentOrganizationId(); // Add this line

      final paymentData = {
        'receipt_number': receiptNumber,
        'student_id': student.id,
        'student_name': '${student.lastName}, ${student.firstName}',
        'payment_type': paymentType,
        'amount': amount,
        'year_level': yearLevel,
        'payment_date': DateTime.now().toIso8601String(),
        'organization_id': orgId, // Add this line
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
      await supabase.from('students').update(updateData).eq('id', student.id);
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

      return (response as List).map((json) => Payment.fromJson(json)).toList();
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

  /// ADD PAYABLE TO SINGLE STUDENT
  /// Increments outstanding_fee or outstanding_fines for one student
  static Future<void> addPayableToStudent({
    required String studentId,
    required String type, // 'Fee' or 'Fine'
    required double amount,
  }) async {
    try {
      // First get current balance
      final response = await supabase
          .from('students')
          .select('outstanding_fee, outstanding_fines')
          .eq('id', studentId)
          .single();

      final currentFee =
          (response['outstanding_fee'] as num?)?.toDouble() ?? 0.0;
      final currentFines =
          (response['outstanding_fines'] as num?)?.toDouble() ?? 0.0;

      // Calculate new balance
      final updateData = <String, dynamic>{};
      if (type == 'Fee') {
        updateData['outstanding_fee'] = currentFee + amount;
      } else {
        updateData['outstanding_fines'] = currentFines + amount;
      }

      // Update student record
      await supabase.from('students').update(updateData).eq('id', studentId);
    } catch (e) {
      throw Exception('Failed to add payable: $e');
    }
  }

  /// ADD PAYABLE TO MULTIPLE STUDENTS (BULK)
  /// Increments outstanding_fee or outstanding_fines for all students
  /// Optionally filtered by year level
  /// Returns the count of students updated
  static Future<int> addPayableBulk({
    required String type, // 'Fee' or 'Fine'
    required double amount,
    String? yearLevel, // Optional filter by year level
  }) async {
    try {
      final orgId = _getCurrentOrganizationId();

      // Build query to get all matching students
      var query = supabase
          .from('students')
          .select('id, outstanding_fee, outstanding_fines')
          .eq('organization_id', orgId);

      if (yearLevel != null) {
        query = query.eq('year_level', yearLevel);
      }

      final students = await query;
      final studentList = students as List;

      if (studentList.isEmpty) {
        return 0;
      }

      // Update each student
      for (final student in studentList) {
        final studentId = student['id'] as String;
        final currentFee =
            (student['outstanding_fee'] as num?)?.toDouble() ?? 0.0;
        final currentFines =
            (student['outstanding_fines'] as num?)?.toDouble() ?? 0.0;

        final updateData = <String, dynamic>{};
        if (type == 'Fee') {
          updateData['outstanding_fee'] = currentFee + amount;
        } else {
          updateData['outstanding_fines'] = currentFines + amount;
        }

        await supabase.from('students').update(updateData).eq('id', studentId);
      }

      return studentList.length;
    } catch (e) {
      throw Exception('Failed to add bulk payables: $e');
    }
  }
}
