import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'admin/screens/admin_dashboard_shell.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'employee/screens/employee_dashboard_shell.dart';
import 'employee/screens/employee_signup_screen.dart';
import 'services/employee_identity_service.dart'; // Updated to new service

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ClubManagerApp());
}

class ClubManagerApp extends StatelessWidget {
  const ClubManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.visibleAppName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final EmployeeIdentityService _identityService = EmployeeIdentityService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen(message: 'Checking authentication...');
        }

        final firebaseUser = snapshot.data;
        if (firebaseUser == null) {
          return const LoginScreen();
        }

        // PHASE 11 FIX: Using the new robust identity resolution
        return FutureBuilder<EmployeeIdentityResult>(
          future: _identityService.resolveByAuthUid(firebaseUser.uid),
          builder: (context, identitySnapshot) {
            if (identitySnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen(message: 'Verifying identity...');
            }

            final result = identitySnapshot.data;

            // Handle non-existent profile (Redirect to Signup)
            if (result == null || !result.exists) {
              return const EmployeeSignupScreen();
            }

            // Handle Blocked/Inactive status
            if (!result.isBookingEligible) {
              return _AccessBlockedScreen(
                title: 'Access Restricted',
                message: result.blockingReason,
                actionLabel: 'Sign Out',
                onActionPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
              );
            }

            final String role = result.user?['role'] ?? 'employee';

            // Route based on FFL Governance Model
            switch (role) {
              case 'admin':
              case 'developer':
              case 'mess_manager':
              case 'mess_supervisor':
                // FIX: Passing userEmail as required by the new Shell
                return AdminDashboardShell(userEmail: firebaseUser.email ?? '');

              case 'employee':
              default:
                return const EmployeeDashboardShell();
            }
          },
        );
      },
    );
  }
}

// --- LoginScreen and Helper Widgets remain consistent with your existing UI ---

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isResetLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorText = 'Please enter both email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.message ?? 'Login failed.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your registered email first.')),
      );
      return;
    }
    setState(() => _isResetLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset email sent. Check your inbox.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error sending reset email.')),
      );
    } finally {
      if (mounted) setState(() => _isResetLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Image.asset('assets/images/fg_logo.png', height: 34, errorBuilder: (_, __, ___) => const SizedBox(height: 34)),
                        Image.asset('assets/images/ffl_logo.png', height: 40, errorBuilder: (_, __, ___) => const SizedBox(height: 40)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(AppConstants.visibleAppName, textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email', hintText: 'Enter registered email'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: (_isLoading || _isResetLoading) ? null : _handleForgotPassword,
                        child: _isResetLoading ? const CircularProgressIndicator(strokeWidth: 2) : const Text('Forgot Password?'),
                      ),
                    ),
                    if (_errorText != null) 
                      Text(_errorText!, style: TextStyle(color: AppColors.error), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _signIn,
                      child: _isLoading ? const CircularProgressIndicator() : const Text('Login'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  final String message;
  const _LoadingScreen({required this.message});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(message)],
        ),
      ),
    );
  }
}

class _AccessBlockedScreen extends StatelessWidget {
  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onActionPressed;

  const _AccessBlockedScreen({required this.title, required this.message, required this.actionLabel, required this.onActionPressed});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              ElevatedButton(onPressed: onActionPressed, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}
