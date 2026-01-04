// lib/screens/payment/payment_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'package:connect_app/theme/tokens.dart';
import '/services/payment_service.dart';

class PaymentSetupScreen extends StatefulWidget {
  const PaymentSetupScreen({Key? key}) : super(key: key);

  @override
  State<PaymentSetupScreen> createState() => _PaymentSetupScreenState();
}

class _PaymentSetupScreenState extends State<PaymentSetupScreen> {
  bool _isProcessing = false;
  final PaymentService _paymentService = PaymentService();

  Future<void> _setupPaymentMethod() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      // ✅ Ensure the user is logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Please log in first.');

      // ✅ Refresh token to avoid UNAUTHENTICATED errors
      await user.getIdToken(true);

      // ✅ Ensure Stripe customer exists
      final ok = await _paymentService.ensureStripeCustomer();
      if (!ok) throw Exception('Could not create Stripe customer.');

      // ✅ Create SetupIntent (server should create + return client_secret)
      final clientSecret = await _paymentService.createSetupIntent();
      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('No client secret returned from backend.');
      }

      // ✅ Init PaymentSheet for SetupIntent
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'Helperly',
          setupIntentClientSecret: clientSecret,
          style: ThemeMode.system,
          // NOTE:
          // If your backend uses ephemeral keys/customer in PaymentSheet,
          // add those params inside PaymentService + pass them here.
        ),
      );

      // ✅ Present PaymentSheet
      await Stripe.instance.presentPaymentSheet();

      // ✅ Retrieve the setup intent and extract payment method id
      final setupIntent = await Stripe.instance.retrieveSetupIntent(clientSecret);
      final paymentMethodId = setupIntent.paymentMethodId;

      if (paymentMethodId == null || paymentMethodId.isEmpty) {
        throw Exception('No payment method ID returned from Stripe.');
      }

      // ✅ Save default payment method on user doc
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'defaultPaymentMethodId': paymentMethodId},
        SetOptions(merge: true),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Card added successfully!')),
      );
      Navigator.pop(context, true);
    } on StripeException catch (e) {
      // User cancel is not really an error UX-wise
      final msg = e.error.localizedMessage ?? 'Stripe error';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Setup failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Add Payment Method'),
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: Center(
        child: _isProcessing
            ? const CircularProgressIndicator()
            : SizedBox(
                width: 240,
                child: ElevatedButton.icon(
                  onPressed: _setupPaymentMethod,
                  icon: const Icon(Icons.credit_card),
                  label: const Text('Set Up Card'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
      ),
    );
  }
}
