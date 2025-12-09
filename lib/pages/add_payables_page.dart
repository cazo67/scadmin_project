import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../models/student_model.dart';
import '../services/payment_service.dart';

/// ADD PAYABLES PAGE
/// Allows adding fees or fines to students (individual or bulk)
class AddPayablesPage extends StatefulWidget {
  const AddPayablesPage({Key? key}) : super(key: key);

  @override
  State<AddPayablesPage> createState() => _AddPayablesPageState();
}

class _AddPayablesPageState extends State<AddPayablesPage> {
  // Form state
  String _paymentType = 'Fee'; // 'Fee' or 'Fine'
  String _applyTo = 'All Members'; // 'All Members' or 'Individual'
  String _selectedYearLevel = 'All Years';
  final _amountController = TextEditingController();
  final _studentSearchController = TextEditingController();

  // Student search state
  Student? _selectedStudent;
  List<Student> _searchResults = [];
  bool _isSearching = false;
  bool _isSubmitting = false;

  // Year levels for dropdown
  final List<String> _yearLevels = [
    'All Years',
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _studentSearchController.dispose();
    super.dispose();
  }

  /// SEARCH STUDENTS
  Future<void> _searchStudents(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final user = supabase.auth.currentUser;
      final orgId = user?.userMetadata?['organization_id'];

      // Search by ID or name
      final response = await supabase
          .from('students')
          .select()
          .eq('organization_id', orgId)
          .or(
            'id.ilike.%$query%,last_name.ilike.%$query%,first_name.ilike.%$query%',
          )
          .limit(10);

      if (mounted) {
        setState(() {
          _searchResults = (response as List)
              .map((json) => Student.fromJson(json))
              .toList();
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// SELECT STUDENT
  void _selectStudent(Student student) {
    setState(() {
      _selectedStudent = student;
      _studentSearchController.text =
          '${student.lastName}, ${student.firstName} (${student.id})';
      _searchResults = [];
    });
  }

  /// CLEAR STUDENT SELECTION
  void _clearStudentSelection() {
    setState(() {
      _selectedStudent = null;
      _studentSearchController.clear();
      _searchResults = [];
    });
  }

  /// ADD PAYABLE
  Future<void> _addPayable() async {
    // Validate amount
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate student selection for individual
    if (_applyTo == 'Individual' && _selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a student'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_applyTo == 'Individual') {
        // Add to single student
        await PaymentService.addPayableToStudent(
          studentId: _selectedStudent!.id,
          type: _paymentType,
          amount: amount,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Added ₱${amount.toStringAsFixed(2)} $_paymentType to ${_selectedStudent!.fullName}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Add to all students (optionally filtered by year level)
        final count = await PaymentService.addPayableBulk(
          type: _paymentType,
          amount: amount,
          yearLevel: _selectedYearLevel == 'All Years'
              ? null
              : _selectedYearLevel,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Added ₱${amount.toStringAsFixed(2)} $_paymentType to $count students',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      // Clear form
      _amountController.clear();
      _clearStudentSelection();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add payable: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Payables',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PAYMENT TYPE TOGGLE
            _buildSectionLabel('Payment Type'),
            const SizedBox(height: 8),
            _buildToggleButtons(
              options: ['Fee', 'Fine'],
              selected: _paymentType,
              onChanged: (value) => setState(() => _paymentType = value),
            ),

            const SizedBox(height: 24),

            // APPLY TO TOGGLE
            _buildSectionLabel('Apply To'),
            const SizedBox(height: 8),
            _buildToggleButtons(
              options: ['All Members', 'Individual'],
              selected: _applyTo,
              onChanged: (value) {
                setState(() {
                  _applyTo = value;
                  if (value == 'All Members') {
                    _clearStudentSelection();
                  }
                });
              },
            ),

            const SizedBox(height: 24),

            // YEAR LEVEL DROPDOWN (only for All Members)
            if (_applyTo == 'All Members') ...[
              _buildSectionLabel('Year Level (Optional)'),
              const SizedBox(height: 8),
              _buildYearLevelDropdown(),
              const SizedBox(height: 24),
            ],

            // STUDENT SEARCH (only for Individual)
            if (_applyTo == 'Individual') ...[
              _buildSectionLabel('Search Student'),
              const SizedBox(height: 8),
              _buildStudentSearch(),
              const SizedBox(height: 24),
            ],

            // AMOUNT INPUT
            _buildSectionLabel('Amount'),
            const SizedBox(height: 8),
            _buildAmountInput(),

            const SizedBox(height: 32),

            // ADD PAYABLE BUTTON
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _addPayable,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  disabledBackgroundColor: Colors.grey[400],
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Add Payable',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// BUILD SECTION LABEL
  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  /// BUILD TOGGLE BUTTONS
  Widget _buildToggleButtons({
    required List<String> options,
    required String selected,
    required Function(String) onChanged,
  }) {
    return Row(
      children: options.map((option) {
        final isSelected = option == selected;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: option == options.first ? 8 : 0,
              left: option == options.last ? 8 : 0,
            ),
            child: GestureDetector(
              onTap: () => onChanged(option),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFE8F5E9) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF1B5E20)
                        : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Text(
                  option,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected
                        ? const Color(0xFF1B5E20)
                        : Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// BUILD YEAR LEVEL DROPDOWN
  Widget _buildYearLevelDropdown() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedYearLevel,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: InputBorder.none,
        ),
        items: _yearLevels.map((level) {
          return DropdownMenuItem(value: level, child: Text(level));
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() => _selectedYearLevel = value);
          }
        },
      ),
    );
  }

  /// BUILD STUDENT SEARCH
  Widget _buildStudentSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search input
        TextField(
          controller: _studentSearchController,
          onChanged: _searchStudents,
          decoration: InputDecoration(
            hintText: 'Search by ID or name...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _selectedStudent != null
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearStudentSelection,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 2),
            ),
          ),
          enabled: _selectedStudent == null,
        ),

        // Search results
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey[200]),
              itemBuilder: (context, index) {
                final student = _searchResults[index];
                return ListTile(
                  title: Text('${student.lastName}, ${student.firstName}'),
                  subtitle: Text('${student.id} • ${student.program ?? 'N/A'}'),
                  onTap: () => _selectStudent(student),
                );
              },
            ),
          ),

        // Selected student display
        if (_selectedStudent != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1B5E20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF1B5E20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_selectedStudent!.lastName}, ${_selectedStudent!.firstName}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_selectedStudent!.id} • ${_selectedStudent!.program ?? 'N/A'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// BUILD AMOUNT INPUT
  Widget _buildAmountInput() {
    return TextField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      decoration: InputDecoration(
        hintText: '0.00',
        prefixText: '₱ ',
        prefixStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 2),
        ),
      ),
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }
}
