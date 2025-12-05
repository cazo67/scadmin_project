import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../main.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:data_table_2/data_table_2.dart';

// ignore: deprecated_member_use
import 'dart:html' as html;

/// REPORTS PAGE
/// Shows student payment data in table format
/// Paid cells are highlighted in green
/// Can export to Excel
class ReportsPage extends StatefulWidget {
  const ReportsPage({Key? key}) : super(key: key);

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  List<Map<String, dynamic>> _studentsData = [];
  List<Map<String, dynamic>> _filteredData = [];
  bool _isLoading = false;

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// LOAD REPORT DATA
  /// Fetches students and their payment status
  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);

    try {
      // Get current organization ID
      final user = supabase.auth.currentUser;
      final orgId = user?.userMetadata?['organization_id'];

      if (orgId == null) {
        throw Exception('No organization found');
      }

      // Fetch all students for this organization
      final studentsResponse = await supabase
          .from('students')
          .select()
          .eq('organization_id', orgId);

      // Fetch all payments for this organization
      final paymentsResponse = await supabase
          .from('payments')
          .select()
          .eq('organization_id', orgId);

      // Create a map of student_id -> payment info
      final paymentsMap = <String, Map<String, dynamic>>{};
      for (var payment in paymentsResponse as List) {
        final studentId = payment['student_id'];
        if (!paymentsMap.containsKey(studentId)) {
          paymentsMap[studentId] = {};
        }
        paymentsMap[studentId]![payment['payment_type']] = payment;
      }

      // Combine students with their payment status
      final data = (studentsResponse as List).map((student) {
        final studentId = student['id'];
        final payments = paymentsMap[studentId] ?? {};

        return {
          'id': student['id'],
          'last_name': student['last_name'],
          'first_name': student['first_name'],
          'college': student['college'],
          'program': student['program'],
          'year_level': student['year_level'],
          'outstanding_fee': student['outstanding_fee'],
          'outstanding_fines': student['outstanding_fines'],
          'fee_paid': payments['Fee'] != null,
          'fines_paid': payments['Fines'] != null,
          'fee_receipt': payments['Fee']?['receipt_number'],
          'fines_receipt': payments['Fines']?['receipt_number'],
          'fee_payment_date': payments['Fee']?['payment_date'], // Add this
          'fines_payment_date': payments['Fines']?['payment_date'], // Add this
        };
      }).toList();

      setState(() {
        _studentsData = data;
        _filteredData = data;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// FILTER STUDENTS BY ID
  void _filterStudents(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredData = _studentsData;
      } else {
        _filteredData = _studentsData
            .where(
              (student) => student['id'].toString().toLowerCase().contains(
                query.toLowerCase(),
              ),
            )
            .toList();
      }
    });
  }

  /// EXPORT TO EXCEL
  Future<void> _exportToExcel() async {
    try {
      // Create Excel workbook
      var excel = Excel.createExcel();
      Sheet sheet = excel['Payment Report'];

      // Add headers
      sheet.appendRow([
        TextCellValue('STUDENT ID'),
        TextCellValue('LAST NAME'),
        TextCellValue('FIRST NAME'),
        TextCellValue('COLLEGE'),
        TextCellValue('PROGRAM'),
        TextCellValue('YEAR LEVEL'),
        TextCellValue('FEE AMOUNT'),
        TextCellValue('FINES AMOUNT'),
        TextCellValue('FEE STATUS'),
        TextCellValue('FEE PAYMENT DATE'),
        TextCellValue('FINES STATUS'),
        TextCellValue('FINES PAYMENT DATE'),
      ]);

      // Style header row
      for (int col = 0; col < 12; col++) {
        var cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
        );
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.green800,
          fontColorHex: ExcelColor.white,
        );
      }

      // Add data rows
      for (var student in _studentsData) {
        // Format payment dates
        String feeDate = '';
        String finesDate = '';

        if (student['fee_payment_date'] != null) {
          final date = DateTime.parse(student['fee_payment_date']);
          feeDate = DateFormat('MM/dd/yyyy hh:mm a').format(date);
        }

        if (student['fines_payment_date'] != null) {
          final date = DateTime.parse(student['fines_payment_date']);
          finesDate = DateFormat('MM/dd/yyyy hh:mm a').format(date);
        }

        sheet.appendRow([
          TextCellValue(student['id']),
          TextCellValue(student['last_name']),
          TextCellValue(student['first_name']),
          TextCellValue(student['college'] ?? ''),
          TextCellValue(student['program'] ?? ''),
          TextCellValue(student['year_level'] ?? ''),
          DoubleCellValue(student['outstanding_fee']),
          DoubleCellValue(student['outstanding_fines']),
          TextCellValue(
            student['fee_paid']
                ? 'PAID'
                : student['outstanding_fee'] > 0
                ? 'UNPAID'
                : 'N/A',
          ),
          TextCellValue(feeDate),
          TextCellValue(
            student['fines_paid']
                ? 'PAID'
                : student['outstanding_fines'] > 0
                ? 'UNPAID'
                : 'N/A',
          ),
          TextCellValue(finesDate),
        ]);

        // Color paid cells green
        int rowIndex = sheet.maxRows - 1;

        // Fee status cell (column 8)
        if (student['fee_paid']) {
          var cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex),
          );
          cell.cellStyle = CellStyle(backgroundColorHex: ExcelColor.green300);
        }

        // Fee date cell (column 9)
        if (student['fee_paid']) {
          var cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex),
          );
          cell.cellStyle = CellStyle(backgroundColorHex: ExcelColor.green300);
        }

        // Fines status cell (column 10)
        if (student['fines_paid']) {
          var cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex),
          );
          cell.cellStyle = CellStyle(backgroundColorHex: ExcelColor.green300);
        }

        // Fines date cell (column 11)
        if (student['fines_paid']) {
          var cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: rowIndex),
          );
          cell.cellStyle = CellStyle(backgroundColorHex: ExcelColor.green300);
        }
      }
      // Save file
      var fileBytes = excel.save();
      if (fileBytes == null) {
        throw Exception('Failed to generate Excel file');
      }

      // Download file
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'payment_report_$timestamp.xlsx';

      if (kIsWeb) {
        // Web: trigger browser download
        final blob = html.Blob([fileBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report downloaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Mobile/Desktop
        String? outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Excel Report',
          fileName: fileName,
        );

        if (outputPath != null) {
          final file = File(outputPath);
          await file.writeAsBytes(fileBytes);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Report exported successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Payment Reports',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1B5E20),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // REFRESH BUTTON
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadReportData,
            tooltip: 'Refresh Data',
          ),

          // EXPORT BUTTON
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: _studentsData.isEmpty ? null : _exportToExcel,
            tooltip: 'Export to Excel',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // SEARCH BAR
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterStudents,
                    decoration: InputDecoration(
                      labelText: 'Search by Student ID',
                      hintText: 'Enter student ID...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _filterStudents('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),

                // TABLE
                // TABLE WITH FIXED HEADER
                Expanded(
                  child: _filteredData.isEmpty
                      ? const Center(child: Text('No students found'))
                      : Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: DataTable2(
                            columnSpacing: 12,
                            horizontalMargin: 12,
                            minWidth: 1400,
                            fixedTopRows: 1, // This fixes the header row
                            headingRowColor: MaterialStateProperty.all(
                              Colors.green[100],
                            ),
                            columns: const [
                              DataColumn2(
                                label: Text(
                                  'STUDENT ID',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                size: ColumnSize.S,
                              ),
                              DataColumn2(
                                label: Text(
                                  'LAST NAME',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                size: ColumnSize.M,
                              ),
                              DataColumn2(
                                label: Text(
                                  'FIRST NAME',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                size: ColumnSize.M,
                              ),
                              DataColumn2(
                                label: Text(
                                  'COLLEGE',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                size: ColumnSize.S,
                              ),
                              DataColumn2(
                                label: Text(
                                  'PROGRAM',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                size: ColumnSize.L,
                              ),
                              DataColumn2(
                                label: Text(
                                  'YEAR LEVEL',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                size: ColumnSize.S,
                              ),
                              DataColumn2(
                                label: Text(
                                  'FEE AMOUNT',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                size: ColumnSize.S,
                              ),
                              DataColumn2(
                                label: Text(
                                  'FINES AMOUNT',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                size: ColumnSize.S,
                              ),
                              DataColumn2(
                                label: Text(
                                  'FEE STATUS',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                size: ColumnSize.L,
                              ),
                              DataColumn2(
                                label: Text(
                                  'FINES STATUS',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                size: ColumnSize.L,
                              ),
                            ],
                            rows: _filteredData.map((student) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(student['id'] ?? '')),
                                  DataCell(Text(student['last_name'] ?? '')),
                                  DataCell(Text(student['first_name'] ?? '')),
                                  DataCell(Text(student['college'] ?? '')),
                                  DataCell(Text(student['program'] ?? '')),
                                  DataCell(Text(student['year_level'] ?? '')),
                                  DataCell(
                                    Text(
                                      '₱${student['outstanding_fee']?.toStringAsFixed(2) ?? '0.00'}',
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      '₱${student['outstanding_fines']?.toStringAsFixed(2) ?? '0.00'}',
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: student['fee_paid']
                                            ? Colors.green[100]
                                            : null,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        student['fee_paid']
                                            ? 'PAID (${student['fee_receipt']})'
                                            : student['outstanding_fee'] > 0
                                            ? 'UNPAID'
                                            : 'N/A',
                                        style: TextStyle(
                                          color: student['fee_paid']
                                              ? Colors.green[900]
                                              : Colors.black,
                                          fontWeight: student['fee_paid']
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: student['fines_paid']
                                            ? Colors.green[100]
                                            : null,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        student['fines_paid']
                                            ? 'PAID (${student['fines_receipt']})'
                                            : student['outstanding_fines'] > 0
                                            ? 'UNPAID'
                                            : 'N/A',
                                        style: TextStyle(
                                          color: student['fines_paid']
                                              ? Colors.green[900]
                                              : Colors.black,
                                          fontWeight: student['fines_paid']
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
