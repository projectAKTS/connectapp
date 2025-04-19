import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

class PaymentSetupScreen extends StatefulWidget {
  const PaymentSetupScreen({Key? key}) : super(key: key);
  @override
  _PaymentSetupScreenState createState() => _PaymentSetupScreenState();
}

class _PaymentSetupScreenState extends State<PaymentSetupScreen> {
  bool _isProcessing = false;
  final _functions = FirebaseFunctions.instance;

  Future<void> _setupPaymentMethod() async {
    setState(() => _isProcessing = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      // Get client secret from your Cloud Function
      final resp = await _functions
          .httpsCallable('createSetupIntent')
          .call(<String, dynamic>{});
      final clientSecret = resp.data['clientSecret'] as String;
      if (clientSecret.isEmpty) throw Exception('No client secret');

      // Initialize PaymentSheet in Setup mode
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'Connect App',
          setupIntentClientSecret: clientSecret,
        ),
      );

      // Present the sheet
      await Stripe.instance.presentPaymentSheet();

      // After success, fetch the SetupIntent to get the paymentMethodId
      // NOTE: you may want a backend call here to retrieve the SetupIntent ID,
      // then use stripe.setupIntents.retrieve(...) and return the payment_method
      // For now we'll fetch the last added payment method on the customer:
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final stripeCustomerId = userDoc.data()?['stripeCustomerId'];
      // This is a simplification: you should retrieve the actual PM from Stripe.
      // Here we just mark that a method exists:
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'defaultPaymentMethodId': 'pm_attached_via_sheet'});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment method set up successfully.')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Setup failed: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Payment Method")),
      body: Center(
        child: _isProcessing
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _setupPaymentMethod,
                child: const Text("Set Up Card"),
              ),
      ),
    );
  }
}
