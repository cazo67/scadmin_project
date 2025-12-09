import 'package:flutter/material.dart';
import '../main.dart';
import '../models/student_model.dart';
import '../services/csv_service.dart';
import '../models/payment_model.dart' as payment_model; // Add prefix

import '../services/payment_service.dart';
import 'payment_confirmation_dialog.dart';
import 'receipt_screen.dart';
import 'upload_disclaimer_dialog.dart';
import 'student_details_page.dart';
import 'add_payables_page.dart';

/// HOME PAGE (Dashboard)
/// Main screen after login - shows upload button and student management options
class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // STUDENT SEARCH STATE
  final _studentIdController = TextEditingController();
  Student? _currentStudent;
  bool _isSearching = false;

  // INPUT STATE
  String _inputDisplay = ''; // Only this one stays

  payment_model.Payment? _studentFeePayment;
  payment_model.Payment? _studentFinesPayment;
  @override
  void dispose() {
    _studentIdController.dispose(); // Clean up controller
    super.dispose();
  }

  /// SEARCH STUDENT BY ID
  /// Fetches student from database and displays their info
  Future<void> _searchStudent() async {
    // Get the ID from input
    final studentId = _studentIdController.text.trim();

    // Validation: Check if ID is not empty
    if (studentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a student ID'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSearching = true);

    try {
      // Query Supabase for student with matching ID
      // Get current user's organization ID
      final user = supabase.auth.currentUser;
      final orgId = user?.userMetadata?['organization_id'];

      // Query Supabase for student with matching ID
      final response = await supabase
          .from('students')
          .select()
          .eq('id', studentId)
          .eq(
            'organization_id',
            orgId,
          ) // Add this line - filter by organization
          .maybeSingle();

      // Check if student found
      if (response == null) {
        // Student not found
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Student ID "$studentId" not found'),
              backgroundColor: Colors.red,
            ),
          );
        }

        setState(() {
          _currentStudent = null; // Clear loaded student
        });
      } else {
        // Student found - convert JSON to Student object
        setState(() {
          _currentStudent = Student.fromJson(response);
          _studentFeePayment = null; // Add this line
          _studentFinesPayment = null; // Add this line
        });
      }
    } catch (e) {
      // Database error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSearching = false);
    }
  }

  /// HANDLE CSV UPLOAD
  /// Shows disclaimer then uploads CSV file
  Future<void> _handleCsvUpload() async {
    // Show disclaimer dialog first
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const UploadDisclaimerDialog(),
    );

    // User cancelled
    if (proceed != true) return;

    // Proceed with upload
    setState(() => _isSearching = true);

    try {
      // Pick and parse CSV
      final students = await CsvService.pickAndParseCsv();

      // User cancelled file picker
      if (students == null) {
        setState(() => _isSearching = false);
        return;
      }

      // Upload to database
      await CsvService.uploadStudents(students);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully uploaded ${students.length} students'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Clear current student display to refresh
      setState(() {
        _currentStudent = null;
        _studentFeePayment = null;
        _studentFinesPayment = null;
        _inputDisplay = '';
        _studentIdController.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  /// HANDLE KEYPAD INPUT
  /// Adds number to input display and controller
  void _onKeypadPressed(String value) {
    setState(() {
      _inputDisplay += value; // Add number to display
      _studentIdController.text = _inputDisplay; // Update controller
    });
  }

  /// CLEAR INPUT
  /// Resets input field and clears loaded student
  void _onClearPressed() {
    setState(() {
      _inputDisplay = '';
      _studentIdController.clear();
      _currentStudent = null;
      _studentFeePayment = null; // Add this line
      _studentFinesPayment = null; // Add this line
    });
  }

  /// BACKSPACE
  /// Removes last character from input
  void _onBackspacePressed() {
    if (_inputDisplay.isNotEmpty) {
      setState(() {
        _inputDisplay = _inputDisplay.substring(0, _inputDisplay.length - 1);
        _studentIdController.text = _inputDisplay;
      });
    }
  }

  /// PROCEED TO PAYMENT
  /// Shows confirmation dialog and processes payment
  Future<void> _proceedPayment(String paymentType) async {
    // Validate student is loaded
    if (_currentStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please search for a student first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Get the amount based on payment type
    final amount = paymentType == 'Fee'
        ? _currentStudent!.outstandingFee
        : _currentStudent!.outstandingFines;

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
        student: _currentStudent!,
        paymentType: paymentType,
        amount: amount,
      ),
    );

    // User cancelled
    if (confirmed != true) return;

    // Process payment
    try {
      // Show loading
      // Hide loading and show success
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();

      // Process payment through service
      final payment = await PaymentService.processPayment(
        student: _currentStudent!,
        paymentType: paymentType,
        amount: amount,
        yearLevel: _currentStudent!.yearLevel ?? '1st Year',
      );

      // Update state with payment info
      setState(() {
        if (paymentType == 'Fee') {
          _studentFeePayment = payment;
          _currentStudent = Student(
            id: _currentStudent!.id,
            lastName: _currentStudent!.lastName,
            firstName: _currentStudent!.firstName,
            college: _currentStudent!.college,
            program: _currentStudent!.program,
            yearLevel: _currentStudent!.yearLevel,
            outstandingFee: 0.0, // Paid
            outstandingFines: _currentStudent!.outstandingFines,
            outstandingUnpaidBalance: _currentStudent!.outstandingUnpaidBalance,
          );
        } else {
          _studentFinesPayment = payment;
          _currentStudent = Student(
            id: _currentStudent!.id,
            lastName: _currentStudent!.lastName,
            firstName: _currentStudent!.firstName,
            college: _currentStudent!.college,
            program: _currentStudent!.program,
            yearLevel: _currentStudent!.yearLevel,
            outstandingFee: _currentStudent!.outstandingFee,
            outstandingFines: 0.0, // Paid
            outstandingUnpaidBalance: _currentStudent!.outstandingUnpaidBalance,
          );
        }
      });

      // Navigate to receipt screen
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ReceiptScreen(payment: payment, student: _currentStudent!),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// SIGN OUT
  Future<void> _signOut() async {
    try {
      await supabase.auth.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed out successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
      }
    }
  }

  /// BUILD STUDENT INFORMATION CARD
  /// Displays student details or empty placeholder
  Widget _buildStudentInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Section header
          const Text(
            'STUDENT INFORMATION',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),

          // Student ID and Year level
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _currentStudent?.id ?? '000000000',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // Year level badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_currentStudent?.yearLevel ?? '0th'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // Name
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentStudent?.lastName ?? 'Last Name',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _currentStudent?.firstName ?? 'First Name',
                style: const TextStyle(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),

          // College and Program
          Text(
            '${_currentStudent?.college ?? 'CAS'} - ${_currentStudent?.program ?? 'BS Information Technology'}',
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.blue[700],
            ),
            overflow: TextOverflow.ellipsis,
          ),

          // Outstanding amounts
          Row(
            children: [
              // Fee amount
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'College Fee',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                        color: _studentFeePayment != null
                            ? Colors.green[50]
                            : null,
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '₱${_studentFeePayment != null ? '0.00' : (_currentStudent?.outstandingFee.toStringAsFixed(2) ?? '0.00')}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Fine amount
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'College Fine',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                        color: _studentFinesPayment != null
                            ? Colors.green[50]
                            : null,
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '₱${_studentFinesPayment != null ? '0.00' : (_currentStudent?.outstandingFines.toStringAsFixed(2) ?? '0.00')}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// BUILD PAYMENT BUTTONS
  /// Two buttons: Proceed Fee Payment and Proceed Fines Payment
  Widget _buildPaymentButtons() {
    return Row(
      children: [
        // FEE PAYMENT BUTTON (Yellow/Gold)
        Expanded(
          child: ElevatedButton(
            onPressed: _currentStudent == null
                ? null
                : () => _proceedPayment('Fee'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107), // Yellow/Gold
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              disabledBackgroundColor: Colors.grey[300],
            ),
            child: const Text(
              'Process Fee Payment',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // FINES PAYMENT BUTTON (Dark Green)
        Expanded(
          child: ElevatedButton(
            onPressed: _currentStudent == null
                ? null
                : () => _proceedPayment('Fines'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107), // Dark green
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              disabledBackgroundColor: Colors.grey[300],
            ),
            child: const Text(
              'Process Fines Payment',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  /// BUILD VIEW FULL DETAILS BUTTON
  /// Navigates to student details page with payment history
  Widget _buildViewFullDetailsButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _currentStudent == null
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        StudentDetailsPage(student: _currentStudent!),
                  ),
                );
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1B5E20),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          disabledBackgroundColor: Colors.grey[300],
        ),
        child: const Text(
          'View Full Details',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// BUILD SEARCH INPUT AND KEYPAD
  /// Input field with numeric keypad for entering student ID
  Widget _buildSearchAndKeypad() {
    return Container(
      padding: const EdgeInsets.all(12),
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
        children: [
          // INPUT FIELD ROW
          Row(
            children: [
              // Text input field
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _inputDisplay.isEmpty ? 'Enter Student ID' : _inputDisplay,
                    style: TextStyle(
                      fontSize: 18,
                      color: _inputDisplay.isEmpty ? Colors.grey : Colors.black,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // SEARCH BUTTON (Green)
              SizedBox(
                width: 60,
                height: 44,
                child: ElevatedButton(
                  onPressed: _isSearching ? null : _searchStudent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search, color: Colors.white),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // NUMERIC KEYPAD - fills remaining space
          Expanded(child: _buildKeypad()),
        ],
      ),
    );
  }

  /// BUILD NUMERIC KEYPAD
  /// 3x4 grid of number buttons (1-9, 0, backspace, clear)
  Widget _buildKeypad() {
    return Column(
      children: [
        // Row 1: 7, 8, 9
        Expanded(child: _buildKeypadRow(['7', '8', '9'])),
        const SizedBox(height: 4),

        // Row 2: 4, 5, 6
        Expanded(child: _buildKeypadRow(['4', '5', '6'])),
        const SizedBox(height: 4),

        // Row 3: 1, 2, 3
        Expanded(child: _buildKeypadRow(['1', '2', '3'])),
        const SizedBox(height: 4),

        // Row 4: Clear, 0, Backspace
        Expanded(
          child: Row(
            children: [
              // CLEAR button
              Expanded(
                child: _buildKeypadButton(
                  'C',
                  onPressed: _onClearPressed,
                  backgroundColor: Colors.red[700]!,
                ),
              ),
              const SizedBox(width: 8),

              // 0 button
              Expanded(
                child: _buildKeypadButton(
                  '0',
                  onPressed: () => _onKeypadPressed('0'),
                ),
              ),
              const SizedBox(width: 8),

              // BACKSPACE button
              Expanded(
                child: _buildKeypadButton(
                  '⌫',
                  onPressed: _onBackspacePressed,
                  backgroundColor: Colors.orange[700]!,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// BUILD KEYPAD ROW
  /// Helper to create a row of 3 number buttons
  Widget _buildKeypadRow(List<String> numbers) {
    return Row(
      children: [
        Expanded(
          child: _buildKeypadButton(
            numbers[0],
            onPressed: () => _onKeypadPressed(numbers[0]),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildKeypadButton(
            numbers[1],
            onPressed: () => _onKeypadPressed(numbers[1]),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildKeypadButton(
            numbers[2],
            onPressed: () => _onKeypadPressed(numbers[2]),
          ),
        ),
      ],
    );
  }

  /// BUILD KEYPAD BUTTON
  /// Individual button for keypad
  Widget _buildKeypadButton(
    String label, {
    required VoidCallback onPressed,
    Color? backgroundColor,
  }) {
    return SizedBox.expand(
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              backgroundColor ?? const Color(0xFF1B5E20), // Dark green default
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// MOBILE LAYOUT (existing vertical layout)
  Widget _buildMobileLayout() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // TOP 50%: Student info, payment buttons, view details
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(child: _buildStudentInfoCard()),
                const SizedBox(height: 4),
                _buildPaymentButtons(),
                const SizedBox(height: 4),
                _buildViewFullDetailsButton(),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // BOTTOM 50%: Keypad
          Expanded(flex: 1, child: _buildSearchAndKeypad()),
        ],
      ),
    );
  }

  /// DESKTOP LAYOUT (side-by-side layout)
  /// DESKTOP LAYOUT (side-by-side layout like your image)
  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.all(16.0), // Reduced from 24
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT SIDE: Student info and payment buttons
          Expanded(
            flex: 3, // Changed from 2 to 3 (takes more space)
            child: Column(
              children: [
                _buildStudentInfoCard(),
                const SizedBox(height: 12), // Reduced from 16
                _buildPaymentButtons(),
                const SizedBox(height: 12),
                _buildViewFullDetailsButton(),
              ],
            ),
          ),

          const SizedBox(width: 16), // Reduced from 24
          // RIGHT SIDE: Search and keypad
          Expanded(
            flex: 2, // Changed from 1 to 2 (takes more space)
            child: _buildSearchAndKeypad(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Detect screen size
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800; // Desktop if wider than 800px
    return Scaffold(
      backgroundColor: Colors.grey[100],

      // TOP APP BAR
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20), // Dark green
        title: Row(
          children: [
            // Organization logo placeholder
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
                    color: Colors.white, // White text
                  ),
                ),
                Text(
                  supabase.auth.currentUser?.email ?? '',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white70, // Light white text
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Three dots menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'logout') {
                _signOut();
              } else if (value == 'upload_csv') {
                _handleCsvUpload();
              } else if (value == 'add_payables') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddPayablesPage(),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'upload_csv',
                child: Row(
                  children: [
                    Icon(Icons.upload_file, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Upload CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'add_payables',
                child: Row(
                  children: [
                    Icon(Icons.add_circle, color: Color(0xFF1B5E20)),
                    SizedBox(width: 8),
                    Text('Add Payables'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }
}
