import 'package:flutter/material.dart';

/// UPLOAD DISCLAIMER DIALOG
/// Shows warning and instructions before CSV upload
class UploadDisclaimerDialog extends StatelessWidget {
  const UploadDisclaimerDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 32),
          const SizedBox(width: 12),
          const Text('CSV Upload Instructions'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // WARNING
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[300]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Uploading will ADD or UPDATE student records. Existing students with the same ID will be updated.',
                      style: TextStyle(color: Colors.orange[900]),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // REQUIRED FORMAT
            const Text(
              'Required CSV Format:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Column Headers (case-sensitive):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• STUDENT ID (required)\n'
                    '• LAST NAME (required)\n'
                    '• FIRST NAME (required)\n'
                    '• COLLEGE\n'
                    '• PROGRAM\n'
                    '• YEAR LEVEL (e.g., "3rd Year")\n'
                    '• FEE AMOUNT\n'
                    '• FINES AMOUNT\n'
                    '• UNPAID BALANCE',
                    style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // EXAMPLE
            const Text(
              'Example Row:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '2022301108, CASTRO, CARLOS FIDEL, CISC, BSIT, 3rd Year, 1000, 0, 0',
                style: TextStyle(fontSize: 10, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        // CANCEL
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        
        // PROCEED
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.upload_file),
          label: const Text('I Understand, Proceed'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1B5E20),
          ),
        ),
      ],
    );
  }
}