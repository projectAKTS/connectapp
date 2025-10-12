import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/firebase_auth_service.dart';
import '../../theme/tokens.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _authService = FirebaseAuthService();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _passwordCtrl  = TextEditingController();
  final _confirmCtrl   = TextEditingController();

  bool _isLoading = false;
  bool _isSocialLoading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final first = _firstNameCtrl.text.trim();
    final last  = _lastNameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass  = _passwordCtrl.text.trim();
    final conf  = _confirmCtrl.text.trim();

    if (first.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First name is required')),
      );
      return;
    }
    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email and password are required')),
      );
      return;
    }
    if (pass != conf) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final fullName = '$first ${last.isEmpty ? '' : last}'.trim();

      final user = await _authService.registerWithEmail(email, pass, fullName);
      if (user == null) throw Exception('Registration failed');

      await user.getIdToken(true);

      final userData = {
        'fullName': fullName,
        'badges': <String>[],
        'location': '',
        'skills': <String>[],
        'interestTags': <String>[],
        'streakDays': 0,
        'lastPostDate': '',
        'xpPoints': 0,
        'helpfulVotesGiven': <Map<String, dynamic>>[],
        'helpfulMarks': 0,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userData, SetOptions(merge: true));

      await user.getIdToken(true);

      // Optional Stripe customer
      try {
        final callable = _functions.httpsCallable('createStripeCustomer');
        await callable();
      } catch (_) {/* ignore */}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registered! Let’s finish onboarding.')),
      );
      Navigator.pushReplacementNamed(context, '/onboarding');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final msg = switch (e.code) {
        'email-already-in-use' => 'That email is already registered.',
        'invalid-email' => 'Invalid email address.',
        'weak-password' => 'Password is too weak.',
        _ => e.message ?? 'Registration failed',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _signUpWithGoogle() async {
    setState(() => _isSocialLoading = true);
    try {
      final u = await _authService.signInWithGoogle();
      if (!mounted) return;
      setState(() => _isSocialLoading = false);
      if (u != null) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // User cancelled; just show a soft message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google sign-in was cancelled.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSocialLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: $e')),
      );
    }
  }

  Future<void> _signUpWithApple() async {
    setState(() => _isSocialLoading = true);
    try {
      final u = await _authService.signInWithApple();
      if (!mounted) return;
      setState(() => _isSocialLoading = false);
      if (u != null) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSocialLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Apple sign-in failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        centerTitle: true,
        elevation: 0,
        title: const Text('Create account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Join the community and start connecting.',
                  style: t.textTheme.bodyMedium),
              const SizedBox(height: 16),

              // Soft card container
              Container(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [AppShadows.soft],
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    // Names row with labels ABOVE fields (no truncation)
                    Row(
                      children: [
                        Expanded(
                          child: _LabeledField(
                            label: 'First name',
                            child: TextField(
                              controller: _firstNameCtrl,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                hintText: 'First name',
                                prefixIcon: Icon(Icons.person_outline,
                                    color: AppColors.muted),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _LabeledField(
                            label: 'Last name (optional)',
                            child: TextField(
                              controller: _lastNameCtrl,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                hintText: 'Last name',
                                prefixIcon: Icon(Icons.person_outline,
                                    color: AppColors.muted),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _LabeledField(
                      label: 'Email',
                      child: TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'you@domain.com',
                          prefixIcon: Icon(Icons.alternate_email,
                              color: AppColors.muted),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _LabeledField(
                      label: 'Password',
                      child: TextField(
                        controller: _passwordCtrl,
                        obscureText: _obscure1,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: 'Min 8 characters',
                          prefixIcon: const Icon(Icons.lock_outline,
                              color: AppColors.muted),
                          suffixIcon: IconButton(
                            icon: Icon(
                                _obscure1 ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _obscure1 = !_obscure1),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _LabeledField(
                      label: 'Confirm password',
                      child: TextField(
                        controller: _confirmCtrl,
                        obscureText: _obscure2,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: 'Repeat password',
                          prefixIcon: const Icon(Icons.lock_outline,
                              color: AppColors.muted),
                          suffixIcon: IconButton(
                            icon: Icon(
                                _obscure2 ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _obscure2 = !_obscure2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _register,
                              child: const Text('Create Account'),
                            ),
                          ),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              const _OrDivider(),
              const SizedBox(height: 12),

              // Social
              _SoftButton(
                icon: Icons.g_mobiledata,
                label: 'Sign up with Google',
                onPressed: _isSocialLoading ? null : _signUpWithGoogle,
                loading: _isSocialLoading,
              ),
              const SizedBox(height: 10),
              _SoftButton(
                icon: Icons.apple,
                label: 'Sign up with Apple',
                onPressed: _isSocialLoading ? null : _signUpWithApple,
                loading: _isSocialLoading,
              ),

              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                child: const Text('Already have an account? Log in'),
              ),

              const SizedBox(height: 8),
              Text(
                'By creating an account, you agree to our Terms & Privacy.',
                style: t.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: t.textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Expanded(child: Divider()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('or', style: Theme.of(context).textTheme.bodyMedium),
      ),
      const Expanded(child: Divider()),
    ]);
  }
}

class _SoftButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;

  const _SoftButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: loading ? null : onPressed,
      icon: Icon(icon, color: AppColors.text),
      label: loading
          ? const SizedBox(
              height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : Text(label),
      style: TextButton.styleFrom(
        backgroundColor: AppColors.button,
        foregroundColor: AppColors.text,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    );
  }
}
