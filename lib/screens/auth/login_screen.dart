// lib/screens/auth/login_screen.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../../services/firebase_auth_service.dart';
import '../../theme/tokens.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (user == null) {
        _showSnack('Login failed. Please try again.');
        return;
      }
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      // Service has its own timeout & throws on failure/cancel.
      final user = await _authService.signInWithGoogle();
      if (!mounted) return;
      if (user == null) {
        // User cancelled the picker/browser
        _showSnack('Google sign-in was cancelled.');
        return;
        }
      Navigator.pushReplacementNamed(context, '/home');
    } on TimeoutException {
      _showSnack('Google sign-in timed out. Please try again.');
    } catch (e) {
      _showSnack('Google sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithApple() async {
    if (_isLoading) return;
    if (!Platform.isIOS && !Platform.isMacOS) {
      _showSnack('Apple Sign-In is only available on Apple devices.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithApple();
      if (!mounted) return;
      if (user == null) {
        _showSnack('Apple sign-in was cancelled.');
        return;
      }
      Navigator.pushReplacementNamed(context, '/home');
    } on TimeoutException {
      _showSnack('Apple sign-in timed out. Please try again.');
    } catch (e) {
      // Common cause for “error 1000” is missing Apple capability / Services ID.
      _showSnack('Apple sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goForgotPassword() {
    if (_isLoading) return;
    Navigator.pushNamed(context, '/forgot-password');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = Text(
      'Welcome back',
      style: Theme.of(context).textTheme.displaySmall,
    );

    final subtitle = Text(
      'Sign in to continue',
      style: Theme.of(context).textTheme.bodyMedium,
    );

    final emailField = TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      decoration: const InputDecoration(
        labelText: 'Email',
        hintText: 'name@example.com',
      ),
    );

    final passField = TextField(
      controller: _passwordController,
      obscureText: true,
      autofillHints: const [AutofillHints.password],
      decoration: const InputDecoration(
        labelText: 'Password',
        hintText: '••••••••',
      ),
    );

    final primaryBtn = SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        child: _isLoading
            ? const SizedBox(
                height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Log in'),
      ),
    );

    final forgotBtn = Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _isLoading ? null : _goForgotPassword,
        child: const Text('Forgot password?'),
      ),
    );

    // Softer social buttons that match your palette (not too green)
    Widget socialBtn({
      required Widget icon,
      required String label,
      required VoidCallback? onTap,
    }) {
      return SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 10),
              Text(label),
            ],
          ),
        ),
      );
    }

    final googleBtn = socialBtn(
      icon: const Icon(Icons.login, color: AppColors.text),
      label: 'Continue with Google',
      onTap: _isLoading ? null : _loginWithGoogle,
    );

    final appleBtn = socialBtn(
      icon: const Icon(Icons.apple, color: AppColors.text),
      label: 'Continue with Apple',
      onTap: _isLoading ? null : _loginWithApple,
    );

    final toSignup = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('New here?', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(width: 6),
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pushReplacementNamed(context, '/register'),
          child: const Text('Create an account'),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        title: const Text(''),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  const SizedBox(height: 6),
                  subtitle,
                  const SizedBox(height: 24),

                  // Card-like surface for inputs
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
                        emailField,
                        const SizedBox(height: 12),
                        passField,
                        const SizedBox(height: 2),
                        forgotBtn,
                        const SizedBox(height: 12),
                        primaryBtn,
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  Row(
                    children: const [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 12),

                  googleBtn,
                  const SizedBox(height: 10),
                  if (Platform.isIOS || Platform.isMacOS) appleBtn,

                  const SizedBox(height: 16),
                  toSignup,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
