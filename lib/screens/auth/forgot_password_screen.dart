// lib/screens/auth/forgot_password_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/firebase_auth_service.dart';
import '../../theme/tokens.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _auth = FirebaseAuthService();
  final _emailCtrl = TextEditingController();
  bool _sending = false;

  void _show(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _sendReset() async {
    if (_sending) return;
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _show('Please enter your email.');
      return;
    }
    setState(() => _sending = true);
    try {
      await _auth.sendPasswordReset(email);
      if (!mounted) return;
      _show('Password reset email sent to $email');
      Navigator.pop(context); // back to Login
    } on TimeoutException {
      _show('Request timed out. Try again.');
    } catch (e) {
      _show('Failed to send reset email: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Forgot your password?',
                      style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 6),
                  Text(
                    'Enter the email you used to create your account. '
                    'We’ll send you a link to reset your password.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [AppShadows.soft],
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            hintText: 'name@example.com',
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _sending ? null : _sendReset,
                            child: _sending
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Send reset link'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
