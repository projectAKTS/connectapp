// lib/screens/auth/login_screen.dart
import 'package:connect_app/l10n/l10n.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:connect_app/widgets/language_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  StreamSubscription<User?>? _authSub;
  bool _navigatingAfterAuth = false;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted || user == null || _navigatingAfterAuth) return;
      if (_isLoading) {
        setState(() => _isLoading = false);
      }
      _navigatingAfterAuth = true;
      _goHome();
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final user = await _authService
          .signInWithEmail(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          )
          .timeout(
            const Duration(seconds: 25),
            onTimeout: () => throw TimeoutException('Login timed out'),
          );
      if (user == null) {
        _showSnack(context.l10n.loginFailed);
        return;
      }
      // Auth listener handles navigation when sign-in is confirmed.
    } catch (e) {
      _showSnack(context.l10n.loginCheckCredentials);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      // ✅ ALWAYS SHOW PICKER
      final user = await _authService.signInWithGoogleAlwaysAsk().timeout(
            const Duration(seconds: 35),
            onTimeout: () => throw TimeoutException('Google sign-in timed out'),
          );
      if (!mounted) return;

      if (user == null) {
        _showSnack(context.l10n.googleCancelled);
        return;
      }
      // Auth listener handles navigation when sign-in is confirmed.
    } on TimeoutException {
      _showSnack(context.l10n.googleTimedOut);
    } catch (e) {
      _showSnack(context.l10n.googleFailed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithApple() async {
    if (_isLoading) return;
    if (!Platform.isIOS && !Platform.isMacOS) {
      _showSnack(context.l10n.appleOnlyApple);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithApple().timeout(
            const Duration(seconds: 35),
            onTimeout: () => throw TimeoutException('Apple sign-in timed out'),
          );
      if (!mounted) return;

      if (user == null) {
        _showSnack(context.l10n.appleCancelled);
        return;
      }
      // Auth listener handles navigation when sign-in is confirmed.
    } on TimeoutException {
      _showSnack(context.l10n.appleTimedOut);
    } catch (e) {
      _showSnack(context.l10n.appleFailed);
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
    _authSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = Text(
      context.l10n.loginWelcomeBack,
      style: Theme.of(context).textTheme.displaySmall,
    );

    final subtitle = Text(
      context.l10n.loginSubtitle,
      style: Theme.of(context).textTheme.bodyMedium,
    );

    final emailField = TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      decoration: InputDecoration(
        labelText: context.l10n.authEmail,
        hintText: context.l10n.authEmailHint,
      ),
    );

    final passField = TextField(
      controller: _passwordController,
      obscureText: true,
      autofillHints: const [AutofillHints.password],
      decoration: InputDecoration(
        labelText: context.l10n.authPassword,
        hintText: '••••••••',
      ),
    );

    final primaryBtn = SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(context.l10n.loginButton),
      ),
    );

    final forgotBtn = Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _isLoading ? null : _goForgotPassword,
        child: Text(context.l10n.loginForgotPassword),
      ),
    );

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
      label: context.l10n.loginContinueGoogle,
      onTap: _isLoading ? null : _loginWithGoogle,
    );

    final appleBtn = socialBtn(
      icon: const Icon(Icons.apple, color: AppColors.text),
      label: context.l10n.loginContinueApple,
      onTap: _isLoading ? null : _loginWithApple,
    );

    final toSignup = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(context.l10n.loginNewHere,
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(width: 6),
        TextButton(
          onPressed: _isLoading
              ? null
              : () => Navigator.pushReplacementNamed(context, '/register'),
          child: Text(context.l10n.loginCreateAccount),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        title: const Text(''),
        actions: const [LanguageButton()],
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
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(context.l10n.authOr),
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
