import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart' show Stripe, StripeException;

/// Result types for payment attempts.
enum PaymentResult {
  success,
  needsSetup, // user has no stored card
  unauthenticated, // user token missing/stale
  failed, // definitive failure (declined, not allowed)
  pending, // outcome unknown or still running: retry with the same operation
}

class PaymentChargeResult {
  final PaymentResult result;
  final String? paymentIntentId;

  /// What the server actually charged (CAD), when it reports it.
  final double? chargedAmount;

  const PaymentChargeResult({
    required this.result,
    this.paymentIntentId,
    this.chargedAmount,
  });
}

class SetupIntentData {
  final String clientSecret;
  final String? customerId;
  final String? ephemeralKeySecret;

  const SetupIntentData({
    required this.clientSecret,
    this.customerId,
    this.ephemeralKeySecret,
  });
}

class PaymentMethodInfo {
  final String id;
  final String? brand;
  final String? last4;
  final int? expMonth;
  final int? expYear;
  final String? funding;

  const PaymentMethodInfo({
    required this.id,
    this.brand,
    this.last4,
    this.expMonth,
    this.expYear,
    this.funding,
  });
}

class PaymentMethodsData {
  final String? defaultPaymentMethodId;
  final List<PaymentMethodInfo> paymentMethods;

  const PaymentMethodsData({
    required this.defaultPaymentMethodId,
    required this.paymentMethods,
  });
}

class PaymentService {
  static PaymentMethodsData? _memoryCache;

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

    debugPrint('🔑 [PaymentService] Refreshing auth token...');
    await user.getIdToken(true);
    // App Check token refresh is non-blocking here. Firebase Functions handles
    // App Check automatically; forcing refresh can fail debug flows and mask
    // the real backend error.
    try {
      final appCheck = await FirebaseAppCheck.instance.getToken(false);
      if (appCheck != null && appCheck.isNotEmpty) {
        debugPrint(
          '🧾 [PaymentService] App Check token present: ${appCheck.substring(0, 12)}...',
        );
      } else {
        debugPrint('⚠️ [PaymentService] App Check token missing.');
      }
    } catch (e) {
      debugPrint('⚠️ [PaymentService] App Check token fetch failed: $e');
    }

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
      final data = Map<String, dynamic>.from(resp.data as Map);
      final id = data['stripeCustomerId'] as String?;
      debugPrint('📦 [PaymentService] Stripe customer ID: $id');
      return id?.isNotEmpty == true;
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        '❌ [PaymentService] FirebaseFunctionsException: ${e.code} | ${e.message}',
      );
      if (e.code == 'unauthenticated') return false;
      rethrow;
    } catch (e, st) {
      debugPrint('❌ [PaymentService] ensureStripeCustomer() error: $e\n$st');
      return false;
    }
  }

  /// Creates a SetupIntent for adding a new payment method.
  Future<SetupIntentData?> createSetupIntent() async {
    try {
      final functions = await _getAuthedFunctions();
      debugPrint('🪄 [PaymentService] Calling createSetupIntent...');
      final callable = functions.httpsCallable(
        'createSetupIntent',
        options: HttpsCallableOptions(timeout: Duration(seconds: 30)),
      );
      final resp = await callable.call();
      final raw = resp.data;
      debugPrint(
        '🧾 [PaymentService] createSetupIntent raw type: ${raw.runtimeType}',
      );
      if (raw is Map) {
        debugPrint(
          '🧾 [PaymentService] createSetupIntent raw keys: ${raw.keys}',
        );
      } else {
        debugPrint('🧾 [PaymentService] createSetupIntent raw: $raw');
      }
      if (raw is String) {
        final clientSecret = raw;
        debugPrint(
          '🎫 [PaymentService] SetupIntent clientSecret: ${clientSecret.substring(0, 10)}...',
        );
        return SetupIntentData(clientSecret: clientSecret);
      }
      if (raw is! Map) {
        debugPrint(
          '❌ [PaymentService] createSetupIntent unexpected response type.',
        );
        return null;
      }
      final data = Map<String, dynamic>.from(raw);
      String? clientSecret = data['clientSecret'] as String?;
      clientSecret ??= data['client_secret'] as String?;
      clientSecret ??= data['setupIntentClientSecret'] as String?;
      clientSecret ??= data['setup_intent_client_secret'] as String?;
      if (clientSecret == null && data['setupIntent'] is Map) {
        final setupIntent = Map<String, dynamic>.from(
          data['setupIntent'] as Map,
        );
        clientSecret = setupIntent['client_secret'] as String?;
      }

      final customerId =
          data['customerId'] as String? ?? data['customer'] as String?;
      final ephemeralKey =
          data['ephemeralKeySecret'] as String? ??
          data['ephemeralKey'] as String?;
      debugPrint(
        '🎫 [PaymentService] SetupIntent clientSecret: ${clientSecret?.substring(0, 10)}...',
      );
      debugPrint('👤 [PaymentService] customerId: ${customerId ?? 'null'}');
      debugPrint(
        '🔐 [PaymentService] ephemeralKeySecret: ${ephemeralKey != null ? 'present' : 'null'}',
      );

      if (clientSecret == null || clientSecret.isEmpty) return null;
      return SetupIntentData(
        clientSecret: clientSecret,
        customerId: customerId,
        ephemeralKeySecret: ephemeralKey,
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        '❌ [PaymentService] createSetupIntent FirebaseError: ${e.code} | ${e.message}',
      );
      if (e.code == 'unauthenticated') return null;
      rethrow;
    } catch (e, st) {
      debugPrint('❌ [PaymentService] createSetupIntent error: $e\n$st');
      return null;
    }
  }

  /// Fetch saved payment methods for the current user.
  Future<PaymentMethodsData> listPaymentMethods() async {
    final functions = await _getAuthedFunctions();
    debugPrint('💳 [PaymentService] Calling listPaymentMethods...');
    final callable = functions.httpsCallable(
      'listPaymentMethods',
      options: HttpsCallableOptions(timeout: Duration(seconds: 30)),
    );
    final response = await callable.call();
    final data = Map<String, dynamic>.from(response.data as Map);

    final defaultId = data['defaultPaymentMethodId'] as String?;
    final rawMethods = (data['paymentMethods'] as List?) ?? const [];
    final methods = rawMethods
        .whereType<Map>()
        .map((m) {
          final map = Map<String, dynamic>.from(m);
          return PaymentMethodInfo(
            id: (map['id'] ?? '').toString(),
            brand: map['brand'] as String?,
            last4: map['last4'] as String?,
            expMonth: map['expMonth'] as int?,
            expYear: map['expYear'] as int?,
            funding: map['funding'] as String?,
          );
        })
        .where((m) => m.id.isNotEmpty)
        .toList();

    final result = PaymentMethodsData(
      defaultPaymentMethodId: defaultId,
      paymentMethods: methods,
    );
    _memoryCache = result;
    await _cachePaymentMethods(result);
    return result;
  }

  /// Read cached cards from user doc (fast path, often served from local cache).
  Future<PaymentMethodsData?> getCachedPaymentMethods() async {
    if (_memoryCache != null) return _memoryCache;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.cache));
      if (!snap.exists) return null;
      final data = snap.data() ?? {};
      final rawMethods = data['paymentMethodsCache'];
      if (rawMethods is! List) return null;

      final methods = rawMethods
          .whereType<Map>()
          .map((m) {
            final map = Map<String, dynamic>.from(m);
            return PaymentMethodInfo(
              id: (map['id'] ?? '').toString(),
              brand: map['brand'] as String?,
              last4: map['last4'] as String?,
              expMonth: map['expMonth'] as int?,
              expYear: map['expYear'] as int?,
              funding: map['funding'] as String?,
            );
          })
          .where((m) => m.id.isNotEmpty)
          .toList();

      final cached = PaymentMethodsData(
        defaultPaymentMethodId:
            (data['paymentMethodsCacheDefaultId'] ??
                    data['defaultPaymentMethodId'])
                as String?,
        paymentMethods: methods,
      );
      _memoryCache = cached;
      return cached;
    } catch (_) {
      return null;
    }
  }

  Future<void> _cachePaymentMethods(PaymentMethodsData data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final payload = {
      'paymentMethodsCacheDefaultId': data.defaultPaymentMethodId ?? '',
      'paymentMethodsCacheUpdatedAt': FieldValue.serverTimestamp(),
      'paymentMethodsCache': data.paymentMethods
          .map(
            (m) => {
              'id': m.id,
              'brand': m.brand,
              'last4': m.last4,
              'expMonth': m.expMonth,
              'expYear': m.expYear,
              'funding': m.funding,
            },
          )
          .toList(),
    };
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(payload, SetOptions(merge: true));
  }

  Future<void> setDefaultPaymentMethod(String paymentMethodId) async {
    final functions = await _getAuthedFunctions();
    debugPrint('💳 [PaymentService] Calling setDefaultPaymentMethod...');
    final callable = functions.httpsCallable(
      'setDefaultPaymentMethod',
      options: HttpsCallableOptions(timeout: Duration(seconds: 30)),
    );
    await callable.call({'paymentMethodId': paymentMethodId});
  }

  Future<void> removePaymentMethod(String paymentMethodId) async {
    final functions = await _getAuthedFunctions();
    debugPrint('💳 [PaymentService] Calling removePaymentMethod...');
    final callable = functions.httpsCallable(
      'removePaymentMethod',
      options: HttpsCallableOptions(timeout: Duration(seconds: 30)),
    );
    await callable.call({'paymentMethodId': paymentMethodId});
  }

  /// Charges the user’s stored default payment method.
  /// Charges a consultation. The server prices it from [durationMinutes] and
  /// [callType]; [amount] is only read by servers older than that change.
  ///
  /// [operationId] identifies one booking attempt; pass the same id for
  /// every retry of that attempt so the server charges at most once.
  Future<PaymentChargeResult> processPayment({
    required String operationId,
    required double amount,
    int? durationMinutes,
    String? callType,
    String? helperId,
  }) async {
    debugPrint('💳 [PaymentService] processPayment() started. Amount: $amount');
    try {
      final functions = await _getAuthedFunctions();
      final callable = functions.httpsCallable(
        'chargeStoredPaymentMethod',
        options: HttpsCallableOptions(timeout: Duration(seconds: 30)),
      );

      debugPrint('📤 [PaymentService] Calling chargeStoredPaymentMethod...');
      final response = await callable.call({
        'operationId': operationId,
        'amount': amount,
        'currency': 'cad',
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
        if (callType != null) 'callType': callType,
        if (helperId != null) 'helperId': helperId,
      });

      final data = Map<String, dynamic>.from(response.data);
      debugPrint('📥 [PaymentService] Response data: ${jsonEncode(data)}');

      final ok = data['success'] == true;
      if (ok) {
        debugPrint('✅ [PaymentService] Payment succeeded.');
        return PaymentChargeResult(
          result: PaymentResult.success,
          paymentIntentId: data['id'] as String?,
          chargedAmount: (data['amount'] as num?)?.toDouble(),
        );
      }

      debugPrint(
        '⚠️ [PaymentService] chargeStoredPaymentMethod returned success=false.',
      );
      return const PaymentChargeResult(result: PaymentResult.failed);
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        '❌ [PaymentService] FirebaseFunctionsException: ${e.code} | ${e.message}',
      );
      switch (e.code) {
        case 'failed-precondition':
          if ((e.message ?? '').contains('No stored payment method')) {
            debugPrint(
              '⚠️ [PaymentService] User needs to add a payment method.',
            );
            return const PaymentChargeResult(result: PaymentResult.needsSetup);
          }
          // Declined, expired attempt or outdated app: final for this
          // operation.
          return const PaymentChargeResult(result: PaymentResult.failed);
        case 'aborted':
        case 'unavailable':
        case 'deadline-exceeded':
        case 'internal':
          return const PaymentChargeResult(result: PaymentResult.pending);
        case 'unauthenticated':
          debugPrint('🚫 [PaymentService] Unauthenticated — tokens invalid.');
          return const PaymentChargeResult(
            result: PaymentResult.unauthenticated,
          );
        default:
          return const PaymentChargeResult(result: PaymentResult.failed);
      }
    } catch (e, st) {
      // Network errors: the charge may or may not have happened.
      debugPrint('❌ [PaymentService] processPayment() Exception: $e');
      debugPrint('🪵 Stack trace:\n$st');
      return const PaymentChargeResult(result: PaymentResult.pending);
    }
  }

  Future<Map<String, dynamic>> cancelConsultation(String consultationId) async {
    final functions = await _getAuthedFunctions();
    debugPrint('💳 [PaymentService] Calling cancelConsultation...');
    final callable = functions.httpsCallable(
      'cancelConsultation',
      options: HttpsCallableOptions(timeout: Duration(seconds: 30)),
    );
    final response = await callable.call({'consultationId': consultationId});
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Books and pays a session in one server call (bookPaidSession). The
  /// server prices it, charges the saved card and writes the booking.
  /// Pass the same [operationId] for every retry of one attempt.
  Future<PaidBookingResult> bookPaidSession({
    required String operationId,
    required String helperId,
    required int durationMinutes,
    required String callType,
    required DateTime scheduledAt,
  }) async {
    try {
      final functions = await _getAuthedFunctions();
      final callable = functions.httpsCallable(
        'bookPaidSession',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
      );
      final response = await callable.call({
        'operationId': operationId,
        'helperId': helperId,
        'durationMinutes': durationMinutes,
        'callType': callType,
        'scheduledAtMs': scheduledAt.millisecondsSinceEpoch,
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['success'] == true) {
        return PaidBookingResult(
          BookingOutcome.booked,
          consultationId: data['consultationId'] as String?,
        );
      }
      if (data['requiresAction'] == true && data['clientSecret'] is String) {
        return PaidBookingResult(
          BookingOutcome.needsBankConfirmation,
          clientSecret: data['clientSecret'] as String,
        );
      }
      return const PaidBookingResult(BookingOutcome.failed);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[PaymentService] bookPaidSession: ${e.code} ${e.message}');
      final message = e.message ?? '';
      switch (e.code) {
        case 'failed-precondition':
          if (message.contains('No stored payment method')) {
            return const PaidBookingResult(BookingOutcome.needsCard);
          }
          if (message.contains('cannot take paid sessions')) {
            return const PaidBookingResult(BookingOutcome.helperNotReady);
          }
          return const PaidBookingResult(BookingOutcome.failed);
        case 'aborted':
        case 'unavailable':
        case 'deadline-exceeded':
        case 'internal':
          return const PaidBookingResult(BookingOutcome.pending);
        case 'unauthenticated':
          return const PaidBookingResult(BookingOutcome.signedOut);
        default:
          return const PaidBookingResult(BookingOutcome.failed);
      }
    } catch (e) {
      // Network error: the charge may or may not have happened; the same
      // operation id makes the retry safe.
      debugPrint('[PaymentService] bookPaidSession error: $e');
      return const PaidBookingResult(BookingOutcome.pending);
    }
  }

  /// Shows the bank's confirmation (3D Secure). Returns false when the
  /// seeker closed it or the bank refused; the server has the final word.
  Future<bool> confirmWithBank(String clientSecret) async {
    try {
      await Stripe.instance.handleNextAction(clientSecret);
      return true;
    } on StripeException catch (e) {
      debugPrint('[PaymentService] bank confirmation: ${e.error.code}');
      return false;
    } catch (e) {
      debugPrint('[PaymentService] bank confirmation error: $e');
      return false;
    }
  }

  /// The seeker reports a problem with a past paid session.
  Future<void> reportSessionProblem(String consultationId, String reason) async {
    final functions = await _getAuthedFunctions();
    await functions
        .httpsCallable(
          'reportSessionProblem',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
        )
        .call({'consultationId': consultationId, 'reason': reason});
  }

  /// The helper's payout account status (also stored by the server).
  Future<PayoutStatus> getPayoutStatus() async {
    final functions = await _getAuthedFunctions();
    final response = await functions
        .httpsCallable(
          'getPayoutStatus',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
        )
        .call();
    final data = Map<String, dynamic>.from(response.data as Map);
    return PayoutStatus(
      connected: data['connected'] == true,
      payoutsEnabled: data['payoutsEnabled'] == true,
      detailsSubmitted: data['detailsSubmitted'] == true,
    );
  }

  /// Opens Stripe's hosted payout setup for the helper.
  Future<bool> openPayoutSetup() async {
    try {
      final functions = await _getAuthedFunctions();
      final response = await functions
          .httpsCallable(
            'createExpressAccountLink',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
          )
          .call();
      final url = (response.data as Map?)?['url'] as String?;
      if (url == null || url.isEmpty) return false;
      return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[PaymentService] payout setup error: $e');
      return false;
    }
  }
}

enum BookingOutcome {
  booked,
  needsCard,
  needsBankConfirmation,
  helperNotReady,
  pending, // unknown or still running: retry with the same operation id
  signedOut,
  failed,
}

class PaidBookingResult {
  final BookingOutcome outcome;
  final String? consultationId;
  final String? clientSecret;

  const PaidBookingResult(this.outcome, {this.consultationId, this.clientSecret});
}

class PayoutStatus {
  final bool connected;
  final bool payoutsEnabled;
  final bool detailsSubmitted;

  const PayoutStatus({
    required this.connected,
    required this.payoutsEnabled,
    required this.detailsSubmitted,
  });
}
