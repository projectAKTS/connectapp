import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../services/firebase_auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _authService   = FirebaseAuthService();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _passwordCtrl  = TextEditingController();

  bool _isLoading = false;
  final _functions  = FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<void> _register() async {
    if (_firstNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First name is required')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final fullName = '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}';

      // 1) register the user with email/password
      final user = await _authService.registerWithEmail(
        _emailCtrl.text.trim(),
        _passwordCtrl.text.trim(),
        fullName,
      );
      if (user == null) throw Exception('Registration failed');

      // force-refresh their auth token so Firestore sees them as signed in
      await user.getIdToken(true);

      // 1.5) now seed their Firestore profile doc
      final userData = {
        'fullName':        fullName,
        'badges':          <String>[],
        'location':        '',
        'skills':          <String>[],
        'interestTags':    <String>[],
        'streakDays':      0,
        'lastPostDate':    '',
        'xpPoints':        0,
        'helpfulVotesGiven': <Map<String, dynamic>>[],
        'helpfulMarks':    0,
      };
      print('DEBUG USER WRITE (signup): ${user.uid} DATA: $userData');

      await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(userData, SetOptions(merge: true));

      await user.getIdToken(true);

      // optional: create Stripe customer
      try {
        final callable = _functions.httpsCallable('createStripeCustomer');
        await callable();
      } catch (_) {
        // ignore CF errors
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registered! Let’s finish onboarding.')),
      );
      Navigator.pushReplacementNamed(context, '/onboarding');

    } catch (e, st) {
      debugPrint('Signup error: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _firstNameCtrl,
                decoration: const InputDecoration(labelText: 'First Name *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _lastNameCtrl,
                decoration: const InputDecoration(labelText: 'Last Name (optional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _register,
                      child: const Text('Sign Up'),
                    ),
                  ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Sign Up with Google'),
                onPressed: () async {
                  final u = await _authService.signInWithGoogle();
                  if (u != null) Navigator.pushReplacementNamed(context, '/home');
                },
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.apple),
                label: const Text('Sign Up with Apple'),
                onPressed: () async {
                  final u = await _authService.signInWithApple();
                  if (u != null) Navigator.pushReplacementNamed(context, '/home');
                },
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                child: const Text('Already have an account? Log in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
