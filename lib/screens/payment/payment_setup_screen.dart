import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '/services/payment_service.dart';

class PaymentSetupScreen extends StatefulWidget {
  const PaymentSetupScreen({Key? key}) : super(key: key);

  @override
  State<PaymentSetupScreen> createState() => _PaymentSetupScreenState();
}

class _PaymentSetupScreenState extends State<PaymentSetupScreen> {
  bool _isProcessing = false;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');
  final PaymentService _paymentService = PaymentService();

  Future<void> _setupPaymentMethod() async {
    setState(() => _isProcessing = true);

    try {
      // ✅ Ensure the user is logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Please log in first.');

      // ✅ Refresh token to avoid UNAUTHENTICATED errors
      await user.getIdToken(true);

      // ✅ Make sure a Stripe customer exists for this user
      final hasCustomer = await _paymentService.ensureStripeCustomer();
      if (!hasCustomer) throw Exception('Could not create Stripe customer.');

      // ✅ Request a SetupIntent from Cloud Functions
      final clientSecret = await _paymentService.createSetupIntent();
      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('No client secret returned from backend.');
      }

      // ✅ Initialize Stripe PaymentSheet for setup intent
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'Helperly',
          setupIntentClientSecret: clientSecret,
          style: ThemeMode.system,
        ),
      );

      // ✅ Present the payment sheet
      await Stripe.instance.presentPaymentSheet();

      // ✅ Retrieve setup intent details to get payment method ID
      final setupIntent =
          await Stripe.instance.retrieveSetupIntent(clientSecret);
      final paymentMethodId = setupIntent.paymentMethodId;

      if (paymentMethodId == null || paymentMethodId.isEmpty) {
        throw Exception('No payment method ID returned from Stripe.');
      }

      // ✅ Save to Firestore under the user's document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
            {'defaultPaymentMethodId': paymentMethodId},
            SetOptions(merge: true),
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Card added successfully!')),
      );

      Navigator.pop(context, true);
    } on StripeException catch (e) {
      debugPrint('❌ Stripe error: ${e.error.localizedMessage}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stripe error: ${e.error.localizedMessage}')),
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ Firebase Functions error: ${e.code} - ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Setup failed: ${e.message}')),
      );
    } catch (e) {
      debugPrint('⚠️ Error during setup: $e');
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
      appBar: AppBar(
        title: const Text('Add Payment Method'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      backgroundColor: Colors.white,
      body: Center(
        child: _isProcessing
            ? const CircularProgressIndicator()
            : ElevatedButton.icon(
                onPressed: _setupPaymentMethod,
                icon: const Icon(Icons.credit_card),
                label: const Text('Set Up Card'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F4C46),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
      ),
    );
  }
}
