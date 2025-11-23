/// STUDENT MODEL
/// This class represents a student record in our database
/// It handles conversion between:
/// - CSV data (from uploaded files)
/// - Supabase database format (JSON)
/// - Dart objects (used in our app)

class Student {
  // FIELDS - These match your database columns
  final String id;                        // Student institutional ID
  final String lastName;                  // Student last name
  final String firstName;                 // Student first name
  final String? college;                  // College (optional)
  final String? program;                  // Program/Course (optional)
  final String? yearLevel;                // Year level (optional)
  final double outstandingFee;            // Money owed for fees
  final double outstandingFines;          // Money owed for fines
  final double outstandingUnpaidBalance;  // Total unpaid balance

  // CONSTRUCTOR
  // This is how we create a Student object in code
  Student({
    required this.id,
    required this.lastName,
    required this.firstName,
    this.college,
    this.program,
    this.yearLevel,
    this.outstandingFee = 0.0,
    this.outstandingFines = 0.0,
    this.outstandingUnpaidBalance = 0.0,
  });

  // FROM CSV ROW
  // Converts a CSV row (Map format) into a Student object
  // Example CSV row: {'id': '12345', 'lastName': 'Doe', ...}
  factory Student.fromCsvRow(Map<String, dynamic> row) {
    return Student(
      id: row['id']?.toString().trim() ?? '',
      lastName: row['lastName']?.toString().trim() ?? '',
      firstName: row['firstName']?.toString().trim() ?? '',
      college: row['college']?.toString().trim(),
      program: row['program']?.toString().trim(),
      yearLevel: row['yearLevel']?.toString().trim(),
      outstandingFee: _parseDouble(row['outstanding_fee']),
      outstandingFines: _parseDouble(row['outstanding_fines']),
      outstandingUnpaidBalance: _parseDouble(row['outstanding_unpaid_balance']),
    );
  }

  // HELPER: Parse string to double safely
  // Handles cases like "100.50", "100", null, or invalid values
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.trim()) ?? 0.0;
    }
    return 0.0;
  }

  // TO JSON (for Supabase)
  // Converts Student object to JSON format for database storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'last_name': lastName,
      'first_name': firstName,
      'college': college,
      'program': program,
      'year_level': yearLevel,
      'outstanding_fee': outstandingFee,
      'outstanding_fines': outstandingFines,
      'outstanding_unpaid_balance': outstandingUnpaidBalance,
    };
  }

  // FROM JSON (from Supabase)
  // Converts database JSON back to Student object
  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      college: json['college']?.toString(),
      program: json['program']?.toString(),
      yearLevel: json['year_level']?.toString(),
      outstandingFee: _parseDouble(json['outstanding_fee']),
      outstandingFines: _parseDouble(json['outstanding_fines']),
      outstandingUnpaidBalance: _parseDouble(json['outstanding_unpaid_balance']),
    );
  }


  // CALCULATED: Total amount owed
  double get totalOwed => outstandingFee + outstandingFines + outstandingUnpaidBalance;

  // DISPLAY: Full name
  String get fullName => '$firstName $lastName';
}
