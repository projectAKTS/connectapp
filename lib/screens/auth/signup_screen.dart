import 'package:connect_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../config/legal_texts.dart';
import '../../services/firebase_auth_service.dart';
import '../../theme/tokens.dart';
import '../settings/legal_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _authService = FirebaseAuthService();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

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

  void _goOnboarding() {
    if (!mounted) return;
    // Route through AuthGate so notification/token/user bootstrap always runs.
    Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
  }

  Future<void> _register() async {
    final first = _firstNameCtrl.text.trim();
    final last = _lastNameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passwordCtrl.text.trim();
    final conf = _confirmCtrl.text.trim();

    if (first.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.signupFirstNameRequired)),
      );
      return;
    }
    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.signupEmailPasswordRequired)),
      );
      return;
    }
    if (pass != conf) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.signupPasswordsDontMatch)),
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

      // Optional Stripe customer
      try {
        final callable = _functions.httpsCallable('createStripeCustomer');
        await callable();
      } catch (_) {
        // ignore
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.signupRegistered)),
      );
      _goOnboarding();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = switch (e.code) {
        'email-already-in-use' => context.l10n.signupEmailInUse,
        'invalid-email' => context.l10n.signupInvalidEmail,
        'weak-password' => context.l10n.signupWeakPassword,
        _ => context.l10n.signupFailed,
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.signupFailed)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUpWithGoogle() async {
    if (_isSocialLoading) return;
    setState(() => _isSocialLoading = true);
    try {
      // ✅ ALWAYS ASK (account picker every time)
      final u = await _authService.signInWithGoogleAlwaysAsk();
      if (!mounted) return;

      if (u == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.googleCancelled)),
        );
        return;
      }

      // After social sign-up, go onboarding (recommended)
      _goOnboarding();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.googleFailed)),
      );
    } finally {
      if (mounted) setState(() => _isSocialLoading = false);
    }
  }

  Future<void> _signUpWithApple() async {
    if (_isSocialLoading) return;
    setState(() => _isSocialLoading = true);
    try {
      final u = await _authService.signInWithApple();
      if (!mounted) return;

      if (u == null) return; // canceled

      _goOnboarding();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.appleFailed)),
      );
    } finally {
      if (mounted) setState(() => _isSocialLoading = false);
    }
  }

  void _openLegal(String title, String markdown) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LegalScreen(title: title, markdown: markdown),
    ));
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
        title: Text(context.l10n.signupTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.signupSubtitle,
                style: t.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
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
                    Row(
                      children: [
                        Expanded(
                          child: _LabeledField(
                            label: context.l10n.signupFirstName,
                            child: TextField(
                              controller: _firstNameCtrl,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                hintText: context.l10n.signupFirstName,
                                prefixIcon: Icon(
                                  Icons.person_outline,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _LabeledField(
                            label: context.l10n.signupLastNameOptional,
                            child: TextField(
                              controller: _lastNameCtrl,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                hintText: context.l10n.signupLastName,
                                prefixIcon: Icon(
                                  Icons.person_outline,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _LabeledField(
                      label: context.l10n.authEmail,
                      child: TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: context.l10n.signupEmailHint,
                          prefixIcon: Icon(
                            Icons.alternate_email,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _LabeledField(
                      label: context.l10n.authPassword,
                      child: TextField(
                        controller: _passwordCtrl,
                        obscureText: _obscure1,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: context.l10n.signupPasswordHint,
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: AppColors.muted,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure1
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setState(() => _obscure1 = !_obscure1),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _LabeledField(
                      label: context.l10n.signupConfirmPassword,
                      child: TextField(
                        controller: _confirmCtrl,
                        obscureText: _obscure2,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: context.l10n.signupRepeatPassword,
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: AppColors.muted,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure2
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () =>
                                setState(() => _obscure2 = !_obscure2),
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
                              child: Text(context.l10n.signupButton),
                            ),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const _OrDivider(),
              const SizedBox(height: 12),
              _SoftButton(
                icon: Icons.g_mobiledata,
                label: context.l10n.signupWithGoogle,
                onPressed: _isSocialLoading ? null : _signUpWithGoogle,
                loading: _isSocialLoading,
              ),
              const SizedBox(height: 10),
              _SoftButton(
                icon: Icons.apple,
                label: context.l10n.signupWithApple,
                onPressed: _isSocialLoading ? null : _signUpWithApple,
                loading: _isSocialLoading,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/login'),
                child: Text(context.l10n.signupHaveAccount),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.signupAgree,
                style: t.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => _openLegal(
                        context.l10n.settingsTerms, LegalTexts.terms),
                    child: Text(context.l10n.settingsTerms),
                  ),
                  Text(context.l10n.signupAnd, style: t.textTheme.bodyMedium),
                  TextButton(
                    onPressed: () => _openLegal(
                        context.l10n.settingsPrivacy, LegalTexts.privacy),
                    child: Text(context.l10n.settingsPrivacy),
                  ),
                ],
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
        Text(
          label,
          style: t.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
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
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(context.l10n.authOr,
              style: Theme.of(context).textTheme.bodyMedium),
        ),
        const Expanded(child: Divider()),
      ],
    );
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
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
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
