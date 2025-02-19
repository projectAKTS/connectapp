import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firebase_auth_service.dart';

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

  /// ✅ Register with email & password
  Future<void> _register() async {
    if (_firstNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('First Name is required!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = userCredential.user;

      if (user != null) {
        final String fullName =
            "${_firstNameController.text.trim()} ${_lastNameController.text.trim()}";

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fullName': fullName,
          'email': _emailController.text.trim(),
          'bio': 'No bio available yet.',
          'followers': [],
          'following': [],
          'postsCount': 0,
          'profilePicture': '',
          'createdAt': FieldValue.serverTimestamp(),
        });

        Navigator.pushReplacementNamed(context, '/home');
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
              TextField(controller: _firstNameController, decoration: const InputDecoration(labelText: 'First Name *')),
              const SizedBox(height: 10),
              TextField(controller: _lastNameController, decoration: const InputDecoration(labelText: 'Last Name (Optional)')),
              const SizedBox(height: 10),
              TextField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 10),
              TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
              const SizedBox(height: 20),

              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                      child: const Text('Register'),
                    ),
              const SizedBox(height: 20),

              // 🔹 Google & Apple Sign-In
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
