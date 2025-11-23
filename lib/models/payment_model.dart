/// PAYMENT MODEL
/// Represents a payment transaction with receipt information
class Payment {
  final String id;
  final String receiptNumber;      // 6-digit OR number (e.g., "002031")
  final String studentId;
  final String studentName;
  final String paymentType;        // "Fee" or "Fines"
  final double amount;
  final String yearLevel;          // Selected year level
  final DateTime paymentDate;
  final DateTime createdAt;

  Payment({
    required this.id,
    required this.receiptNumber,
    required this.studentId,
    required this.studentName,
    required this.paymentType,
    required this.amount,
    required this.yearLevel,
    required this.paymentDate,
    required this.createdAt,
  });

  /// FROM JSON (from Supabase)
  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id']?.toString() ?? '',
      receiptNumber: json['receipt_number']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? '',
      paymentType: json['payment_type']?.toString() ?? '',
      amount: (json['amount'] is int) 
          ? (json['amount'] as int).toDouble() 
          : (json['amount'] as double?) ?? 0.0,
      yearLevel: json['year_level']?.toString() ?? '',
      paymentDate: DateTime.parse(json['payment_date']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  /// TO JSON (for Supabase)
  Map<String, dynamic> toJson() {
    return {
      'receipt_number': receiptNumber,
      'student_id': studentId,
      'student_name': studentName,
      'payment_type': paymentType,
      'amount': amount,
      'year_level': yearLevel,
      'payment_date': paymentDate.toIso8601String(),
    };
  }

  /// FORMAT RECEIPT NUMBER
  /// Ensures 6-digit format with leading zeros (e.g., 2031 → "002031")
  static String formatReceiptNumber(int counter) {
    return counter.toString().padLeft(6, '0');
  }
}// TODO Implement this library.