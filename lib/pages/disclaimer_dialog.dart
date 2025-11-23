import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

/// DISCLAIMER DIALOG
/// Shown once after user changes their temporary password
/// User must acknowledge before accessing the dashboard
class DisclaimerDialog extends StatelessWidget {
  const DisclaimerDialog({Key? key}) : super(key: key);

  /// MARK DISCLAIMER AS SEEN
  /// Updates user metadata so this dialog won't show again
  Future<void> _markDisclaimerAsSeen(BuildContext context) async {
    try {
      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            'hasSeenDisclaimer': true,
          },
        ),
      );
      
      // Close dialog - AuthWrapper will detect change and show dashboard
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700], size: 28),
          const SizedBox(width: 12),
          const Text('Important Notice'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Please keep your account credentials confidential. All activity on this system is logged for transparency and accountability.',
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your actions are being monitored',
                    style: TextStyle(
                      color: Colors.orange[900],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _markDisclaimerAsSeen(context),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text(
            'I Understand',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
}