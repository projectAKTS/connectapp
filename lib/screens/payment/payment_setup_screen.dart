// lib/screens/payment/payment_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
  late Future<PaymentMethodsData> _cardsFuture;
  String? _defaultId;
  List<PaymentMethodInfo> _cards = const [];

  @override
  void initState() {
    super.initState();
    _cardsFuture = _paymentService.listPaymentMethods();
  }

  void _reloadCards() {
    setState(() {
      _cardsFuture = _paymentService.listPaymentMethods();
    });
  }

  Future<void> _setDefaultCard(String id) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await _paymentService.setDefaultPaymentMethod(id);
      _reloadCards();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _removeCard(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove card?'),
        content: const Text('This card will be removed from your account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || _isProcessing) return;

    setState(() => _isProcessing = true);
    try {
      await _paymentService.removePaymentMethod(id);
      _reloadCards();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showCardActions(PaymentMethodInfo info, bool isDefault) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.star_outline),
                title: const Text('Make default'),
                enabled: !isDefault,
                onTap: isDefault
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _setDefaultCard(info.id);
                      },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                title: const Text('Remove card'),
                onTap: () {
                  Navigator.pop(ctx);
                  _removeCard(info.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _setupPaymentMethod() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      // ✅ Ensure the user is logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Please log in first.');

      // ✅ Refresh token to avoid UNAUTHENTICATED errors
      await user.getIdToken(true);

      // ✅ Ensure Stripe customer exists (non-blocking; backend may create on SetupIntent)
      final ok = await _paymentService.ensureStripeCustomer();
      if (!ok) {
        debugPrint('⚠️ Could not confirm Stripe customer; continuing to SetupIntent.');
      }

      // ✅ Create SetupIntent (server should create + return client_secret)
      final setupData = await _paymentService.createSetupIntent();
      if (setupData == null) {
        throw Exception('Payment setup is temporarily unavailable.');
      }

      // ✅ Init PaymentSheet for SetupIntent
      final hasCustomerKeys =
          (setupData.customerId?.isNotEmpty == true) &&
          (setupData.ephemeralKeySecret?.isNotEmpty == true);

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'Connect App',
          setupIntentClientSecret: setupData.clientSecret,
          customerId: hasCustomerKeys ? setupData.customerId : null,
          customerEphemeralKeySecret:
              hasCustomerKeys ? setupData.ephemeralKeySecret : null,
          style: ThemeMode.system,
          // NOTE:
          // If your backend uses ephemeral keys/customer in PaymentSheet,
          // add those params inside PaymentService + pass them here.
        ),
      );

      // ✅ Present PaymentSheet
      await Stripe.instance.presentPaymentSheet();

      // ✅ Retrieve the setup intent and extract payment method id
      final setupIntent =
          await Stripe.instance.retrieveSetupIntent(setupData.clientSecret);
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
      _reloadCards();
    } on StripeException catch (e) {
      final rawMsg = e.error.localizedMessage ?? 'Stripe error';
      final code = e.error.code?.toString().toLowerCase() ?? '';
      final msg = code.contains('canceled') || rawMsg.toLowerCase().contains('cancel')
          ? 'Card setup canceled.'
          : rawMsg;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Setup failed: ${e.code} ${e.message ?? ''}'.trim())),
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
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Payment Method'),
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Text('Add a card', style: textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Used for consultation bookings. You can update it anytime.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: const [AppShadows.soft],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.button,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.credit_card, color: AppColors.text),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Securely save a default card for faster checkout.',
                    style: textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('Saved cards', style: textTheme.titleMedium),
          const SizedBox(height: 10),
          FutureBuilder<PaymentMethodsData>(
            future: _cardsFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Could not load cards', style: textTheme.bodyLarge),
                    const SizedBox(height: 6),
                    Text(
                      snap.error.toString(),
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _reloadCards,
                      child: const Text('Retry'),
                    ),
                  ],
                );
              }

              final data = snap.data!;
              _defaultId = data.defaultPaymentMethodId;
              _cards = data.paymentMethods;
              final methods = _cards;
              if (methods.isEmpty) {
                return Text(
                  'No saved cards yet.',
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                );
              }

              return Column(
                children: methods
                    .map(
                      (m) => _CardRow(
                        info: m,
                        isDefault: m.id == _defaultId,
                        onMore: () => _showCardActions(m, m.id == _defaultId),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          if (_isProcessing)
            const Center(child: CircularProgressIndicator())
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _setupPaymentMethod,
                icon: const Icon(Icons.lock_outline),
                label: Text(_cards.isEmpty ? 'Set up card' : 'Add another card'),
              ),
            ),
        ],
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  final PaymentMethodInfo info;
  final bool isDefault;
  final VoidCallback onMore;

  const _CardRow({
    required this.info,
    required this.isDefault,
    required this.onMore,
  });

  String _brandLabel(String? brand) {
    if (brand == null || brand.isEmpty) return 'Card';
    return brand[0].toUpperCase() + brand.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final expMonth = info.expMonth?.toString().padLeft(2, '0') ?? '--';
    final expYear = info.expYear?.toString() ?? '--';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.soft],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.button,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.credit_card, color: AppColors.text, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_brandLabel(info.brand)} •••• ${info.last4 ?? '----'}',
                  style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Expires $expMonth/$expYear',
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          if (isDefault)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.button,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'Default',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            IconButton(
              onPressed: onMore,
              icon: const Icon(Icons.more_horiz, color: AppColors.muted),
              tooltip: 'Card options',
            ),
        ],
      ),
    );
  }
}
