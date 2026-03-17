import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'admin/screens/admin_dashboard_shell.dart';
import 'employee/screens/employee_dashboard_shell.dart';
import 'employee/screens/employee_signup_screen.dart';
import 'services/user_profile_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MessCafeApp());
}

class MessCafeApp extends StatelessWidget {
  const MessCafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mess & Cafe Automation V1',
      debugShowCheckedModeBanner: false,
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final UserProfileService _userProfileService = UserProfileService();

  String message = 'Sign in to continue';
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        message = 'Please enter email and password.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      message = 'Signing in...';
    });

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final authUser = credential.user;
      final resolvedEmail = authUser?.email ?? email;
      final uid = authUser?.uid;

      final profile = await _userProfileService.resolveCurrentUserProfile(
        userEmail: resolvedEmail,
        authUid: uid,
      );

      if (!mounted) return;

      if (profile != null && !profile.isActive) {
        await FirebaseAuth.instance.signOut();

        setState(() {
          isLoading = false;
          message = 'This account is inactive. Please contact admin.';
        });
        return;
      }

      final resolvedRole = profile?.role ?? AppUserRole.employee;

      switch (resolvedRole) {
        case AppUserRole.developer:
        case AppUserRole.admin:
        case AppUserRole.messManager:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboardShell()),
          );
          break;

        case AppUserRole.messSupervisor:
        case AppUserRole.employee:
        case AppUserRole.unknown:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const EmployeeDashboardShell()),
          );
          break;
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        message = 'Login error: $e';
      });
    }
  }

  void openEmployeeSignup() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EmployeeSignupScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mess & Cafe Automation V1'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => isLoading ? null : login(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : login,
                    child: Text(isLoading ? 'Logging in...' : 'Login'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isLoading ? null : openEmployeeSignup,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Create Employee Account'),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Access Policy',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Employees may create self-service accounts for employee access only.',
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Administrative roles including Developer, Admin, Mess Manager, and Mess Supervisor are created and authorized manually by system administration.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
