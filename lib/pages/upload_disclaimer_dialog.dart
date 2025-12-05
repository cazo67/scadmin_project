import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// UPLOAD DISCLAIMER DIALOG
/// Shows warning and instructions before CSV upload
class UploadDisclaimerDialog extends StatelessWidget {
  const UploadDisclaimerDialog({Key? key}) : super(key: key);

  @override
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.file_upload_outlined,
                    color: Colors.orange[700],
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Batch Student Upload',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF37474F),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Import student records via CSV file',
                      style: TextStyle(fontSize: 14, color: Color(0xFF78909C)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Data Merge Policy info box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF78909C),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF37474F),
                        ),
                        children: [
                          TextSpan(
                            text: 'Data Merge Policy: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF37474F),
                            ),
                          ),
                          TextSpan(
                            text:
                                'Uploading will automatically add new records and ',
                            style: TextStyle(color: Color(0xFF546E7A)),
                          ),
                          TextSpan(
                            text: 'add',
                            style: TextStyle(color: Color(0xFF5C6BC0)),
                          ),
                          TextSpan(
                            text: ' new records and ',
                            style: TextStyle(color: Color(0xFF546E7A)),
                          ),
                          TextSpan(
                            text: 'update',
                            style: TextStyle(color: Color(0xFF5C6BC0)),
                          ),
                          TextSpan(
                            text:
                                ' existing students based on the Student ID match.',
                            style: TextStyle(color: Color(0xFF546E7A)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Column headers section with copy button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'EXPECTED CSV COLUMNS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF78909C),
                    letterSpacing: 0.5,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    // Use tabs for Excel column separation
                    const headerRow =
                        'STUDENT_ID\tLAST_NAME\tFIRST_NAME\tCOLLEGE\tPROGRAM\tYEAR_LEVEL\tFEE_AMOUNT\tFINES_AMOUNT';
                    Clipboard.setData(const ClipboardData(text: headerRow));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Header row copied to clipboard!'),
                        backgroundColor: Color(0xFF1B5E20),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.content_copy, size: 16),
                  label: const Text('Copy Header Row'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1B5E20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Scrollable spreadsheet-style column header strip
            Container(
              height: 80,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: const Color(0xFFE0E0E0)),
                  bottom: BorderSide(color: const Color(0xFFE0E0E0)),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildColumnCard('STUDENT_ID', 'required', true),
                    _buildColumnCard('LAST_NAME', 'required', true),
                    _buildColumnCard('FIRST_NAME', 'required', true),
                    _buildColumnCard('COLLEGE', 'text', false),
                    _buildColumnCard('PROGRAM', 'text', false),
                    _buildColumnCard('YEAR_LEVEL', 'text', false),
                    _buildColumnCard('FEE_AMOUNT', 'number', false),
                    _buildColumnCard('FINES_AMOUNT', 'number', false),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Row format example section
            const Text(
              'DATA ROW EXAMPLE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF78909C),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFECEFF1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '2022301108, CASTRO, CARLOS, CISC, BSIT, 3rd Year, 1000, 0',
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  color: Color(0xFF37474F),
                ),
              ),
            ),
            const SizedBox(height: 12),

            const SizedBox(height: 24),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: const Color(0xFF37474F),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'I Understand, Proceed',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnCard(String columnName, String dataType, bool isRequired) {
    return Container(
      width: 160,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isRequired ? const Color(0xFF4CAF50) : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              columnName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF37474F),
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dataType,
              style: TextStyle(
                fontSize: 11,
                color: isRequired
                    ? const Color(0xFF1B5E20)
                    : const Color(0xFF78909C),
                fontWeight: isRequired ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnBadge(String label, bool isRequired) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isRequired ? const Color(0xFFE8F5E9) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isRequired ? const Color(0xFF4CAF50) : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isRequired ? const Color(0xFF2E7D32) : Colors.grey[700],
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
