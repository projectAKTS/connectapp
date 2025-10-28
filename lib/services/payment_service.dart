import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

/// Result types for payment attempts.
enum PaymentResult {
  success,
  needsSetup,       // user has no stored card
  unauthenticated,  // user token missing/stale
  failed,           // generic failure
}

class PaymentService {
  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Ensures the user is signed in and refreshes their ID token.
  Future<User> _requireUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('❌ [PaymentService] No authenticated user found.');
      throw FirebaseFunctionsException(
        message: 'Not logged in',
        code: 'unauthenticated',
      );
    }
    await user.getIdToken(true); // Force refresh
    debugPrint('👤 [PaymentService] User OK: ${user.uid}');
    return user;
  }

  /// Returns a fresh Functions instance with ensured Auth + App Check tokens.
  Future<FirebaseFunctions> _getAuthedFunctions() async {
    final user = await _requireUser();

    debugPrint('🔑 [PaymentService] Refreshing ID + App Check tokens...');
    await user.getIdToken(true);
    final appCheck = await FirebaseAppCheck.instance.getToken(true);
    debugPrint('🧾 [PaymentService] App Check token: ${appCheck?.substring(0, 12)}...');

    return FirebaseFunctions.instanceFor(region: 'us-central1');
  }

  /// Ensures a Stripe customer exists for this user.
  Future<bool> ensureStripeCustomer() async {
    try {
      final functions = await _getAuthedFunctions();
      debugPrint('💳 [PaymentService] Calling createStripeCustomer...');
      final callable = functions.httpsCallable(
        'createStripeCustomer',
        options: HttpsCallableOptions(timeout: Duration(seconds: 30)),
      );
      final resp = await callable.call();
      final data = Map<String, dynamic>.from(resp.data);
      final id = data['stripeCustomerId'] as String?;
      debugPrint('📦 [PaymentService] Stripe customer ID: $id');
      return id?.isNotEmpty == true;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ [PaymentService] FirebaseFunctionsException: ${e.code} | ${e.message}');
      if (e.code == 'unauthenticated') return false;
      rethrow;
    } catch (e, st) {
      debugPrint('❌ [PaymentService] ensureStripeCustomer() error: $e\n$st');
      return false;
    }
  }

  /// Creates a SetupIntent for adding a new payment method.
  Future<String?> createSetupIntent() async {
    try {
      final functions = await _getAuthedFunctions();
      debugPrint('🪄 [PaymentService] Calling createSetupIntent...');
      final callable = functions.httpsCallable(
        'createSetupIntent',
        options: HttpsCallableOptions(timeout: Duration(seconds: 30)),
      );
      final resp = await callable.call();
      final data = Map<String, dynamic>.from(resp.data);
      final clientSecret = data['clientSecret'] as String?;
      debugPrint('🎫 [PaymentService] SetupIntent clientSecret: ${clientSecret?.substring(0, 10)}...');
      return clientSecret;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ [PaymentService] createSetupIntent FirebaseError: ${e.code}');
      if (e.code == 'unauthenticated') return null;
      rethrow;
    } catch (e, st) {
      debugPrint('❌ [PaymentService] createSetupIntent error: $e\n$st');
      return null;
    }
  }

  /// Charges the user’s stored default payment method.
  Future<PaymentResult> processPayment({required double amount}) async {
    debugPrint('💳 [PaymentService] processPayment() started. Amount: $amount');
    try {
      final functions = await _getAuthedFunctions();
      final callable = functions.httpsCallable(
        'chargeStoredPaymentMethod',
        options: HttpsCallableOptions(timeout: Duration(seconds: 30)),
      );

      debugPrint('📤 [PaymentService] Calling chargeStoredPaymentMethod...');
      final response = await callable.call({
        'amount': amount,
        'currency': 'cad',
      });

      final data = Map<String, dynamic>.from(response.data);
      debugPrint('📥 [PaymentService] Response data: ${jsonEncode(data)}');

      final ok = data['success'] == true;
      if (ok) {
        debugPrint('✅ [PaymentService] Payment succeeded.');
        return PaymentResult.success;
      }

      debugPrint('⚠️ [PaymentService] chargeStoredPaymentMethod returned success=false.');
      return PaymentResult.failed;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ [PaymentService] FirebaseFunctionsException: ${e.code} | ${e.message}');
      switch (e.code) {
        case 'failed-precondition':
          debugPrint('⚠️ [PaymentService] User needs to add a payment method.');
          return PaymentResult.needsSetup;
        case 'unauthenticated':
          debugPrint('🚫 [PaymentService] Unauthenticated — tokens invalid.');
          return PaymentResult.unauthenticated;
        default:
          return PaymentResult.failed;
      }
    } catch (e, st) {
      debugPrint('❌ [PaymentService] processPayment() Exception: $e');
      debugPrint('🪵 Stack trace:\n$st');
      return PaymentResult.failed;
    }
  }

  /// Creates a Stripe Checkout session (optional hosted flow).
  Future<void> createCheckoutSession({
    required String consultationId,
    required double cost,
    required String helperStripeAccountId,
  }) async {
    final functions = await _getAuthedFunctions();
    try {
      debugPrint('🌐 [PaymentService] Calling createStripeCheckoutSession...');
      final callable = functions.httpsCallable(
        'createStripeCheckoutSession',
        options: HttpsCallableOptions(timeout: Duration(seconds: 30)),
      );
      final response = await callable.call({
        'consultationId': consultationId,
        'cost': cost,
        'helperStripeAccountId': helperStripeAccountId,
        'currency': 'cad',
        'successUrl': 'https://yourapp.page.link/success',
        'cancelUrl': 'https://yourapp.page.link/cancel',
      });

      final data = Map<String, dynamic>.from(response.data);
      final checkoutUrl = data['checkoutUrl'] as String?;
      debugPrint('🧾 [PaymentService] checkoutUrl: $checkoutUrl');

      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw Exception('No checkout URL returned.');
      }

      final uri = Uri.parse(checkoutUrl);
      if (!await canLaunchUrl(uri)) {
        throw Exception('Could not launch Stripe checkout URL.');
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      debugPrint('🚀 [PaymentService] Checkout launched successfully.');
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ [PaymentService] createCheckoutSession FirebaseError: ${e.code}');
      if (e.code == 'unauthenticated') {
        throw Exception('Please sign in again.');
      } else {
        rethrow;
      }
    } catch (e, st) {
      debugPrint('❌ [PaymentService] createCheckoutSession error: $e\n$st');
      rethrow;
    }
  }
}
