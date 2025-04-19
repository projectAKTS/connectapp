import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../services/firebase_auth_service.dart';
import '../profile/payment_setup_screen.dart';  // Ensure this route is configured

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

  /// Register with email & password and then set up Stripe payment method.
  Future<void> _register() async {
    if (_firstNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First Name is required!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String fullName =
          "${_firstNameController.text.trim()} ${_lastNameController.text.trim()}";

      final User? user = await _authService.registerWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        fullName,
      );

      if (user != null) {
        // Call the Cloud Function to create a Stripe Customer.
        final HttpsCallable callable =
            FirebaseFunctions.instance.httpsCallable('createStripeCustomer');
        final response = await callable.call({});
        final String stripeCustomerId = response.data['stripeCustomerId'];
        print("Stripe customer created with ID: $stripeCustomerId");

        // Navigate to Payment Setup Screen so the user can add their card.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const PaymentSetupScreen(),
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful. Please set up your payment method.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration failed. Please try again.')),
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'First Name *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name (Optional)'),
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
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
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
