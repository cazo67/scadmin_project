import 'package:flutter/material.dart';
import '../main.dart';
import '../models/student_model.dart';
import '../services/csv_service.dart';

/// HOME PAGE (Dashboard)
/// Main screen after login - shows upload button and student management options
class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // STUDENT SEARCH STATE
  final _studentIdController = TextEditingController(); // Connects to the text input field
  Student? _currentStudent; // Currently loaded student (null if none)
  bool _isSearching = false; // Loading state when searching
  
  // INPUT STATE
  String _inputDisplay = ''; // What shows in the input field

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
      final response = await supabase
          .from('students')
          .select()
          .eq('id', studentId) // 'eq' means equals - exact match
          .maybeSingle(); // Returns one record or null

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
      _currentStudent = null; // Clear loaded student info
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
  /// Handles fee or fine payment
  Future<void> _proceedPayment(String paymentType) async {
    // Check if student is loaded
    if (_currentStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please search for a student first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // TODO: We'll implement payment recording in next steps
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment processing: $paymentType for ${_currentStudent!.fullName}'),
        backgroundColor: Colors.blue,
      ),
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  /// BUILD STUDENT INFORMATION CARD
  /// Displays student details or empty placeholder
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
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              // Year level badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                    const Text(
                      'Year',
                      style: TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Name
          Text(
            _currentStudent?.lastName ?? 'Last Name',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            _currentStudent?.firstName ?? 'First Name Second Name',
            style: const TextStyle(fontSize: 16),
          ),
          
          const SizedBox(height: 4),
          
          // College and Program
          Text(
            '${_currentStudent?.college ?? 'CAS'} - ${_currentStudent?.program ?? 'BS Information Technology'}',
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.blue[700],
            ),
          ),
          
          const Divider(height: 24),
          
          // Student number label
          const Text(
            'NO. 000000',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          
          const SizedBox(height: 16),
          
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
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            '₱',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _currentStudent?.outstandingFee.toStringAsFixed(2) ?? '0.00',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            '₱',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _currentStudent?.outstandingFines.toStringAsFixed(2) ?? '0.00',
                            style: const TextStyle(
                              fontSize: 24,
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
            onPressed: _currentStudent == null ? null : () => _proceedPayment('Fee'),
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
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        // FINES PAYMENT BUTTON (Dark Green)
        Expanded(
          child: ElevatedButton(
            onPressed: _currentStudent == null ? null : () => _proceedPayment('Fines'),
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
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
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
          // INPUT FIELD ROW
          Row(
            children: [
              // Text input field
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        const SizedBox(height: 8),
        
        // Row 2: 4, 5, 6
        _buildKeypadRow(['4', '5', '6']),
        const SizedBox(height: 8),
        
        // Row 3: 1, 2, 3
        _buildKeypadRow(['1', '2', '3']),
        const SizedBox(height: 8),
        
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
              child: _buildKeypadButton('0', onPressed: () => _onKeypadPressed('0')),
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
          child: _buildKeypadButton(numbers[0], onPressed: () => _onKeypadPressed(numbers[0])),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildKeypadButton(numbers[1], onPressed: () => _onKeypadPressed(numbers[1])),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildKeypadButton(numbers[2], onPressed: () => _onKeypadPressed(numbers[2])),
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
        backgroundColor: backgroundColor ?? const Color(0xFF1B5E20), // Dark green default
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

 @override
  Widget build(BuildContext context) {
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
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ORG ABBREVIATION',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'ORG ACRONYM',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Three dots menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'logout') {
                _signOut();
              } else if (value == 'test_data') {
                _createTestData();
              }
            },
            itemBuilder: (context) => [
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

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // STUDENT INFORMATION CARD
              _buildStudentInfoCard(),
              
              const SizedBox(height: 16),
              
              // PAYMENT BUTTONS
              _buildPaymentButtons(),
              
              const SizedBox(height: 16),
              
              // SEARCH INPUT AND KEYPAD
              _buildSearchAndKeypad(),
            ],
          ),
        ),
      ),
    );
  }
}