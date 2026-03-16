import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'admin/screens/admin_dashboard_shell.dart';
import 'employee/screens/employee_dashboard_shell.dart';
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
  final emailController = TextEditingController(text: 'testmanager@ffc.local');
  final passwordController = TextEditingController(text: 'Test@12345');
  final UserProfileService _userProfileService = UserProfileService();

  String message = 'Sign in to continue';
  bool isLoading = false;

  Future<void> login() async {
    setState(() {
      isLoading = true;
      message = 'Signing in...';
    });

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final authUser = credential.user;
      final email = authUser?.email ?? emailController.text.trim();
      final uid = authUser?.uid;

      final profile = await _userProfileService.resolveCurrentUserProfile(
        userEmail: email,
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: emailController,
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
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : login,
                    child: Text(isLoading ? 'Logging in...' : 'Login'),
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
