import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/login_page.dart';
import 'pages/force_password_change_page.dart';
import 'pages/disclaimer_dialog.dart';

import 'pages/home_page.dart';
// Your Supabase credentials
const supabaseUrl = 'https://ochzxjzjqkamhvzrezhs.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9jaHp4anpqcWthbWh2enJlemhzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM1NTMwNTIsImV4cCI6MjA3OTEyOTA1Mn0.YzgtL-scURT4j2izPSp3dug0PnScvSGjTI-p9niZcKk';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Payment App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

/// AUTH WRAPPER
/// Handles routing based on authentication state and user metadata
/// Flow: Login -> Check metadata -> Force password change OR Disclaimer OR Dashboard
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        // Check if user is logged in
        if (snapshot.hasData) {
          final session = snapshot.data!.session;
          if (session != null) {
            // User is logged in - check their metadata
            final user = supabase.auth.currentUser;
            final metadata = user?.userMetadata ?? {};
            
            // Check if using temporary password
            final isTemporaryPassword = metadata['isTemporaryPassword'] ?? false;
            if (isTemporaryPassword == true) {
              // Force password change
              return const ForcePasswordChangePage();
            }
            
            // Check if user has seen disclaimer
            final hasSeenDisclaimer = metadata['hasSeenDisclaimer'] ?? false;
            if (hasSeenDisclaimer == false) {
              // Show disclaimer dialog
              WidgetsBinding.instance.addPostFrameCallback((_) {
                showDialog(
                  context: context,
                  barrierDismissible: false, // Cannot dismiss by tapping outside
                  builder: (context) => const DisclaimerDialog(),
                );
              });
            }
            
            // User has completed setup - show dashboard
            return const HomePage();
          }
        }
        
        // Not logged in - show login page
        return const LoginPage();
      },
    );
  }
}


