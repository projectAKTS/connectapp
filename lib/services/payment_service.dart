// lib/services/payment_service.dart
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

/// Result types for payment attempts.
enum PaymentResult {
  success,
  needsSetup,        // user has no stored card
  unauthenticated,   // user token missing/stale
  blocked,           // App Check blocked / attestation failed
  failed,            // generic failure
}

class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<User> _requireUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseFunctionsException(
        message: 'Not logged in',
        code: 'unauthenticated',
      );
    }
    await user.getIdToken(true);
    return user;
  }

  /// Gets fresh tokens; if AppCheck is failing, throw a clear error.
  Future<void> _refreshTokens() async {
    final user = await _requireUser();

    await user.getIdToken(true);

    try {
      await FirebaseAppCheck.instance.getToken(true);
    } catch (e) {
      // App attestation failures often appear here
      debugPrint('❌ [PaymentService] AppCheck token error: $e');
      rethrow;
    }
  }

  bool _looksLikeAppCheckBlocked(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('app attestation failed') ||
        s.contains('permission_denied') ||
        s.contains('firebase_app_check') ||
        s.contains('appcheck') ||
        s.contains('403');
  }

  /// Ensures a Stripe customer exists for this user.
  Future<bool> ensureStripeCustomer() async {
    try {
      await _refreshTokens();

      final callable = _functions.httpsCallable(
        'createStripeCustomer',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

      final resp = await callable.call();
      final data = Map<String, dynamic>.from(resp.data);
      final id = data['stripeCustomerId'] as String?;
      debugPrint('📦 [PaymentService] Stripe customer ID: $id');
      return id?.isNotEmpty == true;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ [PaymentService] Functions error: ${e.code} | ${e.message}');
      if (e.code == 'unauthenticated') return false;
      rethrow;
    } catch (e) {
      if (_looksLikeAppCheckBlocked(e)) {
        debugPrint('🚫 [PaymentService] AppCheck blocked.');
        return false;
      }
      debugPrint('❌ [PaymentService] ensureStripeCustomer() error: $e');
      return false;
    }
  }

  /// Creates a SetupIntent and returns its client secret.
  Future<String?> createSetupIntent() async {
    try {
      await _refreshTokens();

      final callable = _functions.httpsCallable(
        'createSetupIntent',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

      final resp = await callable.call();
      final data = Map<String, dynamic>.from(resp.data);
      return data['clientSecret'] as String?;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ [PaymentService] createSetupIntent: ${e.code} | ${e.message}');
      if (e.code == 'unauthenticated') return null;
      rethrow;
    } catch (e) {
      debugPrint('❌ [PaymentService] createSetupIntent error: $e');
      return null;
    }
  }

  /// Adds/updates a saved card using Stripe PaymentSheet (SetupIntent).
  /// Returns blocked if AppCheck/attestation is failing.
  Future<PaymentResult> setupPaymentMethod() async {
    try {
      // Make sure Stripe customer exists.
      final ok = await ensureStripeCustomer();
      if (!ok) {
        return PaymentResult.blocked; // often AppCheck blocked in your case
      }

      final clientSecret = await createSetupIntent();
      if (clientSecret == null || clientSecret.isEmpty) {
        return PaymentResult.failed;
      }

      // Initialize PaymentSheet for SetupIntent
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          setupIntentClientSecret: clientSecret,
          merchantDisplayName: 'Connect App',
          allowsDelayedPaymentMethods: true,
          style: ThemeMode.system,
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      return PaymentResult.success;
    } catch (e) {
      debugPrint('❌ [PaymentService] setupPaymentMethod error: $e');
      if (_looksLikeAppCheckBlocked(e)) return PaymentResult.blocked;
      return PaymentResult.failed;
    }
  }

  /// Charges the user’s stored default payment method.
  Future<PaymentResult> processPayment({required double amount}) async {
    try {
      await _refreshTokens();

      final callable = _functions.httpsCallable(
        'chargeStoredPaymentMethod',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

      final response = await callable.call({
        'amount': amount,
        'currency': 'cad',
      });

      final data = Map<String, dynamic>.from(response.data);
      debugPrint('📥 [PaymentService] charge response: ${jsonEncode(data)}');

      final ok = data['success'] == true;
      if (ok) return PaymentResult.success;

      return PaymentResult.failed;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ [PaymentService] Functions: ${e.code} | ${e.message}');
      switch (e.code) {
        case 'failed-precondition':
          return PaymentResult.needsSetup;
        case 'unauthenticated':
          return PaymentResult.unauthenticated;
        default:
          return PaymentResult.failed;
      }
    } catch (e) {
      debugPrint('❌ [PaymentService] processPayment error: $e');
      if (_looksLikeAppCheckBlocked(e)) return PaymentResult.blocked;
      return PaymentResult.failed;
    }
  }

  /// Hosted Checkout (optional)
  Future<void> createCheckoutSession({
    required String consultationId,
    required double cost,
    required String helperStripeAccountId,
  }) async {
    await _refreshTokens();

    final callable = _functions.httpsCallable(
      'createStripeCheckoutSession',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
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
    if (checkoutUrl == null || checkoutUrl.isEmpty) {
      throw Exception('No checkout URL returned.');
    }

    final uri = Uri.parse(checkoutUrl);
    if (!await canLaunchUrl(uri)) {
      throw Exception('Could not launch checkout URL.');
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
