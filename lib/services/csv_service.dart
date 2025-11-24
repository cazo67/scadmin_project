import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import '../models/student_model.dart';
import '../main.dart';

/// CSV SERVICE
/// Handles all CSV file operations: picking, parsing, validating, and uploading
class CsvService {
  
  // CSV COLUMN CONFIGURATION
  // Maps user-friendly CSV headers to system format
  
  // USER'S CSV HEADERS (what you see in Excel)
  static const String USER_COL_ID = 'STUDENT ID';
  static const String USER_COL_LAST_NAME = 'LAST NAME';
  static const String USER_COL_FIRST_NAME = 'FIRST NAME';
  static const String USER_COL_COLLEGE = 'COLLEGE';
  static const String USER_COL_PROGRAM = 'PROGRAM';
  static const String USER_COL_YEAR_LEVEL = 'YEAR LEVEL';
  static const String USER_COL_FEE = 'FEE AMOUNT';
  static const String USER_COL_FINES = 'FINES AMOUNT';
  static const String USER_COL_BALANCE = 'UNPAID BALANCE';
  
  // SYSTEM COLUMN NAMES (used internally)
  static const String SYS_COL_ID = 'id';
  static const String SYS_COL_LAST_NAME = 'lastName';
  static const String SYS_COL_FIRST_NAME = 'firstName';
  static const String SYS_COL_COLLEGE = 'college';
  static const String SYS_COL_PROGRAM = 'program';
  static const String SYS_COL_YEAR_LEVEL = 'yearLevel';
  static const String SYS_COL_FEE = 'outstanding_fee';
  static const String SYS_COL_FINES = 'outstanding_fines';
  static const String SYS_COL_BALANCE = 'outstanding_unpaid_balance';

  // REQUIRED COLUMNS (using user-friendly names)
  static const List<String> REQUIRED_COLUMNS = [
    USER_COL_ID,
    USER_COL_LAST_NAME,
    USER_COL_FIRST_NAME,
  ];
  
  // COLUMN MAPPING (Excel header → System name)
  static const Map<String, String> COLUMN_MAPPING = {
    USER_COL_ID: SYS_COL_ID,
    USER_COL_LAST_NAME: SYS_COL_LAST_NAME,
    USER_COL_FIRST_NAME: SYS_COL_FIRST_NAME,
    USER_COL_COLLEGE: SYS_COL_COLLEGE,
    USER_COL_PROGRAM: SYS_COL_PROGRAM,
    USER_COL_YEAR_LEVEL: SYS_COL_YEAR_LEVEL,
    USER_COL_FEE: SYS_COL_FEE,
    USER_COL_FINES: SYS_COL_FINES,
    USER_COL_BALANCE: SYS_COL_BALANCE,
  };

  /// PICK AND PARSE CSV FILE
  /// Opens file picker, reads CSV, validates, and returns Student objects
  /// Returns: List of Student objects or null if cancelled/failed
  static Future<List<Student>?> pickAndParseCsv() async {
    try {
      // STEP 1: Open file picker to select CSV file
      // allowMultiple: false - only one file at a time
      // type: custom with ['csv'] - only show CSV files
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      // User cancelled file picker
      if (result == null) return null;

      // STEP 2: Read file content as bytes
      final bytes = result.files.first.bytes;
      if (bytes == null) {
        throw Exception('Could not read file content');
      }

      // STEP 3: Convert bytes to string (CSV text)
      final csvString = utf8.decode(bytes);

      // STEP 4: Parse CSV string into rows
      // Using csv package to handle proper CSV parsing (handles quotes, commas, etc.)
      final List<List<dynamic>> csvTable = const CsvToListConverter().convert(
        csvString,
        eol: '\n',
      );

      // Check if CSV is empty
      if (csvTable.isEmpty) {
        throw Exception('CSV file is empty');
      }

      // STEP 5: Extract headers (first row)
      final headers = csvTable.first.map((e) => e.toString().trim()).toList();

      // STEP 6: Validate required columns exist
      _validateHeaders(headers);

      // STEP 7: Parse data rows (skip header row)
      final List<Student> students = [];
      final Set<String> seenIds = {}; // Track duplicate IDs

      for (int i = 1; i < csvTable.length; i++) {
        final row = csvTable[i];
        
        // Skip empty rows
        if (row.every((cell) => cell.toString().trim().isEmpty)) {
          continue;
        }

        // Convert row array to Map using headers
        // Map user-friendly headers to system format
        final Map<String, dynamic> rowMap = {};
        for (int j = 0; j < headers.length; j++) {
          if (j < row.length) {
            final userHeader = headers[j];
            // Map to system column name (or use original if no mapping exists)
            final systemHeader = COLUMN_MAPPING[userHeader] ?? userHeader;
            rowMap[systemHeader] = row[j];
          }
        }

        // Create Student object from row
        final student = Student.fromCsvRow(rowMap);

        // Validate student ID is not empty
        if (student.id.isEmpty) {
          throw Exception('Row ${i + 1}: Student ID is required');
        }

        // Check for duplicate IDs in CSV
        if (seenIds.contains(student.id)) {
          throw Exception('Row ${i + 1}: Duplicate student ID: ${student.id}');
        }
        seenIds.add(student.id);

        students.add(student);
      }

      // Check if we got any valid students
      if (students.isEmpty) {
        throw Exception('No valid student records found in CSV');
      }

      return students;

    } catch (e) {
      // Re-throw with more context
      throw Exception('CSV parsing error: $e');
    }
  }

  /// VALIDATE CSV HEADERS
  /// Checks if all required columns exist in the CSV
  static void _validateHeaders(List<String> headers) {
    final missingColumns = <String>[];
    
    for (final required in REQUIRED_COLUMNS) {
      if (!headers.contains(required)) {
        missingColumns.add(required);
      }
    }

    if (missingColumns.isNotEmpty) {
      throw Exception(
        'Missing required columns: ${missingColumns.join(", ")}\n'
        'Expected columns: ${REQUIRED_COLUMNS.join(", ")}'
      );
    }
  }

  /// UPLOAD STUDENTS TO SUPABASE
  /// Inserts student records into the database
  /// Uses upsert: updates if ID exists, inserts if new
  static Future<void> uploadStudents(List<Student> students) async {
    try {
      // Convert Student objects to JSON for database
      final List<Map<String, dynamic>> jsonData = 
          students.map((s) => s.toJson()).toList();

      // UPSERT to Supabase
      // onConflict: 'id' - if student ID already exists, update instead of error
      await supabase.from('students').upsert(
        jsonData,
        onConflict: 'id',
      );

    } catch (e) {
      throw Exception('Database upload error: $e');
    }
  }
}