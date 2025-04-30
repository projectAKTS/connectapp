import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../services/firebase_auth_service.dart';
import '../profile/payment_setup_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  // Point at your Cloud Functions region
  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<void> _register() async {
    if (_firstNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First Name is required!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final fullName =
          "${_firstNameController.text.trim()} ${_lastNameController.text.trim()}";

      // 1) Sign up the user
      final user = await _authService.registerWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        fullName,
      );

      if (user == null) {
        throw Exception('Registration failed—no user returned.');
      }

      // 2) Force-refresh the ID token so the function sees them as signed in
      await user.getIdToken(true);

      // 3) Call your createStripeCustomer onCall function
      final callable =
          _functions.httpsCallable('createStripeCustomer');
      final response = await callable();
      final stripeCustomerId = response.data['stripeCustomerId'] as String;

      // 4) Success: navigate to payment setup
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Registered! Now please set up your payment method.')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const PaymentSetupScreen(),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unauthenticated') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Auth failed. Please log in and try again.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Function error: ${e.message}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _firstNameController,
                decoration:
                    const InputDecoration(labelText: 'First Name *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _lastNameController,
                decoration:
                    const InputDecoration(labelText: 'Last Name (Optional)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const Text('Register'),
                    ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Sign Up with Google'),
                onPressed: () async {
                  await _authService.signInWithGoogle();
                },
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.apple),
                label: const Text('Sign Up with Apple'),
                onPressed: () async {
                  await _authService.signInWithApple();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
