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

  // Make sure this matches your deployed region!
  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<void> _setupPaymentMethod() async {
    setState(() => _isProcessing = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('You must be logged in to add a payment method.');

      // Refresh the ID token so cloud function sees a valid auth context
      await user.getIdToken(true);

      // 1) Call your v2 onCall function
      final resp = await _functions
          .httpsCallable('createSetupIntent')
          .call(); // no extra data needed

      final clientSecret = resp.data['clientSecret'] as String;
      if (clientSecret.isEmpty) throw Exception('No client secret returned.');

      // 2) Initialize the native PaymentSheet in “Setup” mode
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'Connect App',
          setupIntentClientSecret: clientSecret,
        ),
      );

      // 3) Present the sheet to collect & save the card
      await Stripe.instance.presentPaymentSheet();

      // 4) Record that we have a method – your backend should have updated Firestore,
      //    but here we can optimistically mark it:
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'defaultPaymentMethodId': 'attached_via_setup'});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment method set up successfully.')),
      );
      Navigator.pop(context);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unauthenticated') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in before adding a payment method.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Setup failed: ${e.message}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Setup failed: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
