import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart';
import '../models/student_model.dart';
import '../services/csv_service.dart';
import '../models/payment_model.dart' as payment_model; // Add prefix

import '../services/payment_service.dart';
import 'payment_confirmation_dialog.dart';
import 'receipt_screen.dart';
import 'upload_disclaimer_dialog.dart';
import 'reports_page.dart'; // Add this line

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

  @override
  void initState() {
    super.initState();
    // Listen to text changes for live search
    _studentIdController.addListener(_onSearchTextChanged);
    _loadRecentTransactions();
  }

  // INPUT STATE
  String _inputDisplay = ''; // Only this one stays

  // LIVE SEARCH STATE
  List<Student> _searchResults = [];
  Timer? _debounceTimer;
  bool _showSearchResults = false;
  final FocusNode _searchFocusNode = FocusNode();

  payment_model.Payment? _studentFeePayment;
  payment_model.Payment? _studentFinesPayment;

  // PAYABLES SELECTION STATE
  final Map<String, bool> _selectedPayables = {};
  double _totalSelected = 0.0;

  // RECENT TRANSACTIONS STATE
  List<payment_model.Payment> _recentTransactions = [];
  @override
  void dispose() {
    _debounceTimer?.cancel();
    _studentIdController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// HANDLE SEARCH TEXT CHANGES
  /// Triggers live search with debouncing
  void _onSearchTextChanged() {
    final query = _studentIdController.text.trim();

    // Cancel previous timer
    _debounceTimer?.cancel();

    // Clear results if input is empty
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    // Set new timer for debounced search (300ms delay)
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performLiveSearch(query);
    });
  }

  /// PERFORM LIVE SEARCH
  /// Searches for students matching the input query
  Future<void> _performLiveSearch(String query) async {
    if (query.isEmpty) return;

    try {
      final user = supabase.auth.currentUser;
      final orgId = user?.userMetadata?['organization_id'];

      print('🔍 Live search triggered for query: "$query"');

      // Search for students whose ID starts with query OR name contains query
      final response = await supabase
          .from('students')
          .select()
          .eq('organization_id', orgId)
          .or(
            'id.ilike.$query%,last_name.ilike.%$query%,first_name.ilike.%$query%',
          )
          .limit(10);

      if (mounted) {
        setState(() {
          _searchResults = (response as List)
              .map((json) => Student.fromJson(json))
              .toList();
          _showSearchResults = _searchResults.isNotEmpty;
          print(
            '✅ Found ${_searchResults.length} results, showing dropdown: $_showSearchResults',
          );
        });
      }
    } catch (e) {
      print('❌ Live search error: $e');
      // Silently fail for live search
      if (mounted) {
        setState(() {
          _searchResults = [];
          _showSearchResults = false;
        });
      }
    }
  }

  /// SELECT STUDENT FROM SEARCH RESULTS
  /// Loads selected student and clears search results
  void _selectStudent(Student student) {
    // Remove listener temporarily to prevent triggering search
    _studentIdController.removeListener(_onSearchTextChanged);

    setState(() {
      _currentStudent = student;
      _studentFeePayment = null;
      _studentFinesPayment = null;
      _inputDisplay = student.id;
      _studentIdController.text = student.id;
      _searchResults = [];
      _showSearchResults = false;
      _selectedPayables.clear();
      _totalSelected = 0.0;
    });

    _searchFocusNode.unfocus();

    // Re-add listener after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _studentIdController.addListener(_onSearchTextChanged);
      }
    });
  }

  /// LOAD RECENT TRANSACTIONS
  /// Fetches the 10 most recent payments
  Future<void> _loadRecentTransactions() async {
    try {
      final user = supabase.auth.currentUser;
      final orgId = user?.userMetadata?['organization_id'];

      if (orgId == null) {
        print('No organization ID found for user');
        return;
      }

      final response = await supabase
          .from('payments')
          .select()
          .eq('organization_id', orgId)
          .order('created_at', ascending: false)
          .limit(10);

      if (mounted && response != null) {
        setState(() {
          _recentTransactions = (response as List)
              .map((json) => payment_model.Payment.fromJson(json))
              .toList();
        });
        print('✅ Loaded ${_recentTransactions.length} recent transactions');
      }
    } catch (e) {
      print('❌ Error loading recent transactions: $e');
      if (mounted) {
        setState(() {
          _recentTransactions = [];
        });
      }
    }
  }

  /// TOGGLE PAYABLE SELECTION
  void _togglePayableSelection(String key, double amount) {
    setState(() {
      _selectedPayables[key] = !(_selectedPayables[key] ?? false);
      _calculateTotal();
    });
  }

  /// SELECT ALL PAYABLES
  void _selectAllPayables() {
    if (_currentStudent == null) return;
    setState(() {
      _selectedPayables['fee'] = _currentStudent!.outstandingFee > 0;
      _selectedPayables['fines'] = _currentStudent!.outstandingFines > 0;
      _calculateTotal();
    });
  }

  /// CALCULATE TOTAL SELECTED
  void _calculateTotal() {
    double total = 0.0;
    if (_currentStudent != null) {
      if (_selectedPayables['fee'] == true)
        total += _currentStudent!.outstandingFee;
      if (_selectedPayables['fines'] == true)
        total += _currentStudent!.outstandingFines;
    }
    _totalSelected = total;
  }

  /// CLEAR SELECTION
  void _clearSelection() {
    setState(() {
      _selectedPayables.clear();
      _totalSelected = 0.0;
    });
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

    // Clear search results dropdown immediately
    setState(() {
      _isSearching = true;
      _searchResults = [];
      _showSearchResults = false;
    });

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
          _selectedPayables.clear();
          _totalSelected = 0.0;
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

  /// CREATE TEST DATA
  /// Adds sample students to database for testing
  /// This is temporary - we'll remove it later when CSV upload is ready
  Future<void> _createTestData() async {
    try {
      // Sample students data
      final testStudents = [
        {
          'id': '2021001',
          'last_name': 'Dela Cruz',
          'first_name': 'Juan',
          'college': 'CCS',
          'program': 'BSCS',
          'year_level': '3',
          'outstanding_fee': 1500.50,
          'outstanding_fines': 200.0,
          'outstanding_unpaid_balance': 100.25,
        },
        {
          'id': '2021002',
          'last_name': 'Santos',
          'first_name': 'Maria',
          'college': 'CBA',
          'program': 'BSBA',
          'year_level': '2',
          'outstanding_fee': 2000.0,
          'outstanding_fines': 0.0,
          'outstanding_unpaid_balance': 500.0,
        },
        {
          'id': '2021003',
          'last_name': 'Reyes',
          'first_name': 'Pedro',
          'college': 'COED',
          'program': 'BEED',
          'year_level': '4',
          'outstanding_fee': 1000.0,
          'outstanding_fines': 150.75,
          'outstanding_unpaid_balance': 0.0,
        },
      ];

      // Insert into Supabase using upsert (won't create duplicates)
      await supabase.from('students').upsert(testStudents);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test data created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create test data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      _inputDisplay += value;
      _studentIdController.text = _inputDisplay;
    });
    // Live search will trigger automatically via controller listener
  }

  /// CLEAR INPUT
  /// Resets input field and clears loaded student
  void _onClearPressed() {
    setState(() {
      _inputDisplay = '';
      _studentIdController.clear();
      _currentStudent = null;
      _studentFeePayment = null;
      _studentFinesPayment = null;
      _searchResults = [];
      _showSearchResults = false;
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();

      // Process payment through service
      final payment = await PaymentService.processPayment(
        student: _currentStudent!,
        paymentType: paymentType,
        amount: amount,
        yearLevel: _currentStudent!.yearLevel ?? '1st Year',
      );

      // Update state with payment info BEFORE navigating
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
            outstandingFee: 0.0,
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
            outstandingFines: 0.0,
            outstandingUnpaidBalance: _currentStudent!.outstandingUnpaidBalance,
          );
        }
        // Clear selections after payment
        _selectedPayables.clear();
        _totalSelected = 0.0;
      });

      // Navigate to receipt screen
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ReceiptScreen(payment: payment, student: _currentStudent!),
        ),
      );

      // Reload recent transactions to show the new payment
      await _loadRecentTransactions();

      // Show success message after returning from receipt screen
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment successful! OR: ${payment.receiptNumber}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
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

  /// OPEN REPORTS PAGE
  Future<void> _openReports() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ReportsPage()),
    );
  }

  /// BUILD STUDENT INFORMATION CARD
  /// Displays student details or empty placeholder
  Widget _buildStudentInfoCard() {
    return Container(
      padding: const EdgeInsets.all(10),
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
          const Divider(),

          // Student ID
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _currentStudent?.id ?? '000000000',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // Year level badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    Text(
                      _currentStudent?.yearLevel ?? '0th',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text('Year', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Name
          Text(
            _currentStudent?.lastName ?? 'Last Name',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          Text(
            _currentStudent?.firstName ?? 'First Name Second Name',
            style: const TextStyle(fontSize: 20),
          ),

          const SizedBox(height: 4),

          // College and Program
          Text(
            '${_currentStudent?.college ?? 'CAS'} - ${_currentStudent?.program ?? 'BS Information Technology'}',
            style: TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: Colors.blue[700],
            ),
          ),

          const Divider(height: 12),

          // Student number label
          const Text(
            'NO. 000000',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),

          const SizedBox(height: 4),

          // Outstanding amounts
          Row(
            children: [
              // Fee amount
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'College Fee Amount',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                        color: _studentFeePayment != null
                            ? Colors.green[50]
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Amount or PAID badge
                          if (_studentFeePayment != null) ...[
                            // PAID Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green[700],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PAID',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'OR: ${_studentFeePayment!.receiptNumber}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ] else ...[
                            // Outstanding amount
                            Row(
                              children: [
                                const Text(
                                  '₱',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _currentStudent?.outstandingFee
                                          .toStringAsFixed(2) ??
                                      '0.00',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Fine amount
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'College Fine Amount:',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            '₱',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _currentStudent?.outstandingFines.toStringAsFixed(
                                  2,
                                ) ??
                                '0.00',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              disabledBackgroundColor: Colors.grey[300],
            ),
            child: const Text(
              'Proceed Fee Payment',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // FINES PAYMENT BUTTON (Dark Green)
        Expanded(
          child: ElevatedButton(
            onPressed: _currentStudent == null
                ? null
                : () => _proceedPayment('Fines'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20), // Dark green
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              disabledBackgroundColor: Colors.grey[300],
            ),
            child: const Text(
              'Proceed Fines Payment',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  /// BUILD SEARCH INPUT AND KEYPAD
  /// Input field with numeric keypad for entering student ID
  Widget _buildSearchAndKeypad() {
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
        children: [
          // INPUT FIELD ROW WITH SEARCH RESULTS
          Column(
            children: [
              Row(
                children: [
                  // Text input field
                  Expanded(
                    child: TextField(
                      controller: _studentIdController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: 'Enter Student ID',
                        hintStyle: const TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF1B5E20),
                            width: 2,
                          ),
                        ),
                      ),
                      style: const TextStyle(fontSize: 18),
                      keyboardType: TextInputType.text,
                      onSubmitted: (_) => _searchStudent(),
                      onChanged: (value) {
                        setState(() {
                          _inputDisplay = value;
                        });
                      },
                    ),
                  ),

                  const SizedBox(width: 8),

                  // SEARCH BUTTON (Green)
                  SizedBox(
                    width: 60,
                    height: 48,
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

              // SEARCH RESULTS DROPDOWN (positioned after input)
              if (_showSearchResults && _searchResults.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  constraints: const BoxConstraints(maxHeight: 250),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: const Color(0xFF1B5E20),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: Colors.grey[200]),
                      itemBuilder: (context, index) {
                        final student = _searchResults[index];
                        return InkWell(
                          onTap: () => _selectStudent(student),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${student.id} - ${student.lastName}, ${student.firstName}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1B5E20),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${student.college ?? 'N/A'} - ${student.program ?? 'N/A'}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: Color(0xFF1B5E20),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // NUMERIC KEYPAD
          _buildKeypad(),
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
        _buildKeypadRow(['7', '8', '9']),
        const SizedBox(height: 4),

        // Row 2: 4, 5, 6
        _buildKeypadRow(['4', '5', '6']),
        const SizedBox(height: 4),

        // Row 3: 1, 2, 3
        _buildKeypadRow(['1', '2', '3']),
        const SizedBox(height: 4),

        // Row 4: Clear, 0, Backspace
        Row(
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
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            backgroundColor ?? const Color(0xFF1B5E20), // Dark green default
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// BUILD RECENT TRANSACTIONS SIDEBAR
  Widget _buildRecentTransactionsSidebar() {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey[300]!, width: 1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!, width: 1.5),
              ),
            ),
            child: const Text(
              'RECENT TRANSACTIONS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: _recentTransactions.isEmpty
                ? const Center(
                    child: Text(
                      'No transactions yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: _recentTransactions.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final payment = _recentTransactions[index];
                      final time = payment.createdAt;
                      final timeStr =
                          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} ${time.hour >= 12 ? 'PM' : 'AM'}';

                      return Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              payment.studentName.isNotEmpty
                                  ? payment.studentName
                                  : payment.studentId,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$timeStr • ID: ${payment.studentId}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Paid ₱ ${payment.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1B5E20),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// BUILD NEW STUDENT PROFILE CARD
  Widget _buildNewStudentProfileCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
      ),
      child: Column(
        children: [
          // Header
          const Text(
            'Student Profile',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D5016),
            ),
          ),
          const SizedBox(height: 16),

          // Content
          _currentStudent == null
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      // Avatar placeholder
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person,
                          size: 70,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // No student text
                      const Text(
                        'NO STUDENT SELECTED',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      // Placeholder ID
                      Text(
                        'ID: --',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      // Placeholder dashes
                      Text(
                        '--',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '--',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                      // Status badge placeholder
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E0E0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Waiting for input',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      // Avatar
                      Container(
                        width: 140,
                        height: 140,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD4E8D4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 70,
                          color: Color(0xFF2D5016),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Name
                      Text(
                        '${_currentStudent!.lastName.toUpperCase()}, ${_currentStudent!.firstName.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      // ID
                      Text(
                        'ID: ${_currentStudent!.id}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 6),
                      // Program
                      Text(
                        _currentStudent!.program ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      // Year/College
                      Text(
                        '${_currentStudent!.yearLevel ?? ''} / ${_currentStudent!.college ?? ''}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 20),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4E8D4),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Active / Enrolled',
                          style: TextStyle(
                            color: Color(0xFF2D5016),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  /// BUILD OUTSTANDING PAYABLES TABLE
  Widget _buildOutstandingPayablesTable() {
    final bool hasStudent = _currentStudent != null;
    final payables = hasStudent
        ? [
            {
              'key': 'fee',
              'desc': 'College Fee (1st Sem)',
              'amount': _currentStudent!.outstandingFee,
            },
            {
              'key': 'fines',
              'desc': 'Late Registration Fine',
              'amount': _currentStudent!.outstandingFines,
            },
          ]
        : [];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Outstanding Payables',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D5016),
                ),
              ),
              TextButton(
                onPressed: hasStudent ? _selectAllPayables : null,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4CAF50),
                  padding: EdgeInsets.zero,
                ),
                child: const Text(
                  'Select All',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Content Area
          !hasStudent
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 100),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Scan a student ID to view payables',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Column Headers
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12, top: 8),
                      child: Row(
                        children: [
                          const SizedBox(width: 40),
                          const Expanded(
                            child: Text(
                              'Description',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          const Text(
                            'Amount',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Table Rows
                    ...payables.map((item) {
                      final isSelected =
                          _selectedPayables[item['key'] as String] ?? false;
                      final amount = item['amount'] as double;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 40,
                              child: Checkbox(
                                value: isSelected,
                                onChanged: amount > 0
                                    ? (val) => _togglePayableSelection(
                                        item['key'] as String,
                                        amount,
                                      )
                                    : null,
                                activeColor: const Color(0xFF1B5E20),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                item['desc'] as String,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Text(
                              amount > 0
                                  ? '₱ ${amount.toStringAsFixed(2)}'
                                  : '₱ ${amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: item['key'] == 'fines' && amount > 0
                                    ? Colors.red
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),

          // Footer with Total and Button
          const SizedBox(height: 24),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Selected',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₱ ${_totalSelected.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: _totalSelected > 0
                          ? const Color(0xFF2D5016)
                          : Colors.grey[400],
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: _totalSelected > 0
                    ? () => _proceedPayment('Fee')
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _totalSelected > 0
                      ? const Color(0xFFFFC107)
                      : Colors.grey[300],
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Process Payment',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// BUILD NEW SEARCH BAR (centered, larger)
  Widget _buildNewSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.grey, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _studentIdController,
              focusNode: _searchFocusNode,
              decoration: const InputDecoration(
                hintText: 'Enter Student ID',
                hintStyle: TextStyle(fontSize: 20, color: Colors.grey),
                border: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 20),
              onSubmitted: (_) => _searchStudent(),
              onChanged: (value) {
                setState(() {
                  _inputDisplay = value;
                });
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Press Enter',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  /// MOBILE LAYOUT (existing vertical layout)
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            _buildStudentInfoCard(),
            const SizedBox(height: 8),
            _buildPaymentButtons(),
            const SizedBox(height: 8),
            _buildSearchAndKeypad(),
          ],
        ),
      ),
    );
  }

  /// NEW DESKTOP LAYOUT (matching the pasted image)
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // LEFT SIDEBAR: Recent Transactions
        _buildRecentTransactionsSidebar(),

        // MAIN CONTENT
        Expanded(
          child: Container(
            color: Colors.grey[50],
            child: Stack(
              children: [
                Column(
                  children: [
                    // SEARCH BAR (top)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey[300]!,
                            width: 1.5,
                          ),
                        ),
                      ),
                      child: _buildNewSearchBar(),
                    ),

                    // TWO COLUMN GRID (Profile | Payables)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // LEFT: Student Profile
                            Expanded(
                              flex: 2,
                              child: _buildNewStudentProfileCard(),
                            ),
                            const SizedBox(width: 24),
                            // RIGHT: Outstanding Payables
                            Expanded(
                              flex: 3,
                              child: _buildOutstandingPayablesTable(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // SEARCH RESULTS DROPDOWN (overlaid)
                if (_showSearchResults && _searchResults.isNotEmpty)
                  Positioned(
                    top: 70, // Position below search bar
                    left: 24,
                    right: 24,
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 250),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: const Color(0xFF1B5E20),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          separatorBuilder: (context, index) =>
                              Divider(height: 1, color: Colors.grey[200]),
                          itemBuilder: (context, index) {
                            final student = _searchResults[index];
                            return InkWell(
                              onTap: () => _selectStudent(student),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${student.id} - ${student.lastName}, ${student.firstName}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1B5E20),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${student.college ?? 'N/A'} - ${student.program ?? 'N/A'}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Color(0xFF1B5E20),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
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
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.school,
                color: Color(0xFF1B5E20),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              supabase.auth.currentUser?.userMetadata?['organization_name'] ??
                  'CISC Cashier',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
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
              } else if (value == 'test_data') {
                _createTestData();
              } else if (value == 'upload_csv') {
                _handleCsvUpload();
              } else if (value == 'reports') {
                _openReports();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reports',
                child: Row(
                  children: [
                    Icon(Icons.analytics, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('View Reports'),
                  ],
                ),
              ),
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
                value: 'test_data',
                child: Row(
                  children: [
                    Icon(Icons.add_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Create Test Data'),
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
