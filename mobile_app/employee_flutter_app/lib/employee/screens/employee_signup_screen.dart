import 'package:flutter/material.dart';

import '../../services/employee_registration_service.dart';

class EmployeeSignupScreen extends StatefulWidget {
  const EmployeeSignupScreen({super.key});

  @override
  State<EmployeeSignupScreen> createState() => _EmployeeSignupScreenState();
}

class _EmployeeSignupScreenState extends State<EmployeeSignupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _employeeNoController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cnicLast4Controller = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _acceptedNotice = false;

  @override
  void dispose() {
    _employeeNoController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _cnicLast4Controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_acceptedNotice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please accept the Privacy & Usage Notice before registering.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await EmployeeRegistrationService().registerEmployee(
        employeeNo: _employeeNoController.text.trim(),
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        cnicLast4: _cnicLast4Controller.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      if (result == 'created') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully. Please sign in.'),
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your request has been submitted for admin approval.',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
    );
  }

  Widget _buildNoticeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy & Usage Notice',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            const Text(
              'This app is for Fatima Fertilizer mess & café services only. '
              'Your information, including employee number, name, phone number, '
              'CNIC last 4 digits, and login credentials, is used only for '
              'account authentication, meal reservations, and service management.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Activity may be logged for security and audit purposes. '
              'Do not share your login credentials. By creating an account, '
              'you consent to this use of your data.',
            ),
            const SizedBox(height: 8),
            const Text(
              'For assistance, contact the club office through email at "mngt.club@fatima-group.com".',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Employee Account'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Employee Self-Registration',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Fill in your employee details exactly as recorded in the company database. '
                        'If your data matches the employee master, your employee account can be created. '
                        'If your data does not match, your request may be forwarded for admin review.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _employeeNoController,
                textCapitalization: TextCapitalization.characters,
                decoration: _inputDecoration(
                  'Employee Number',
                  hint: 'e.g. FFL-00000, ESB-0000, OSL-00000, FAS-00000',
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return 'Employee number is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fullNameController,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDecoration(
                  'Full Name',
                  hint: 'Enter your full name',
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return 'Full name is required.';
                  }
                  if (text.length < 3) {
                    return 'Enter a valid full name.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration(
                  'Phone Number',
                  hint: '03XXXXXXXXX',
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return 'Phone number is required.';
                  }
                  if (text.length < 11) {
                    return 'Enter a valid phone number.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cnicLast4Controller,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                  'CNIC Last 4 Digits',
                  hint: '1234',
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return 'CNIC last 4 digits are required.';
                  }
                  if (text.length != 4) {
                    return 'Enter exactly 4 digits.';
                  }
                  if (int.tryParse(text) == null) {
                    return 'Only digits are allowed.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration(
                  'Email',
                  hint: 'yourname@fatima-group.com',
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return 'Email is required.';
                  }
                  if (!text.contains('@')) {
                    return 'Enter a valid email address.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: _inputDecoration('Password'),
                validator: (value) {
                  final text = value ?? '';
                  if (text.isEmpty) {
                    return 'Password is required.';
                  }
                  if (text.length < 6) {
                    return 'Password must be at least 6 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: _inputDecoration('Confirm Password'),
                validator: (value) {
                  final text = value ?? '';
                  if (text.isEmpty) {
                    return 'Please confirm your password.';
                  }
                  if (text != _passwordController.text) {
                    return 'Passwords do not match.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildNoticeCard(),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _acceptedNotice,
                onChanged: (value) {
                  setState(() {
                    _acceptedNotice = value ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'I agree to the Privacy & Usage Notice and understand that this account is for official mess & café use only.',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _isLoading || !_acceptedNotice ? null : _register,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Register'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
