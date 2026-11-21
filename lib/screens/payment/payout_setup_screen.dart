import 'package:connect_app/l10n/l10n.dart';
import 'package:connect_app/config/mvp_features.dart';
import 'package:connect_app/screens/payment/payments_disabled_screen.dart';
import 'package:connect_app/theme/tokens.dart';
import 'package:flutter/material.dart';

import '/services/payment_service.dart';

/// Helpers connect a Stripe Express account here to receive their share of
/// paid sessions (docs/PAID_SESSIONS_DESIGN.md). Stripe hosts the form; the
/// status is read again when the helper comes back to the app.
class PayoutSetupScreen extends StatefulWidget {
  const PayoutSetupScreen({super.key});

  @override
  State<PayoutSetupScreen> createState() => _PayoutSetupScreenState();
}

class _PayoutSetupScreenState extends State<PayoutSetupScreen>
    with WidgetsBindingObserver {
  final PaymentService _payments = PaymentService();
  PayoutStatus? _status;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    if (!MvpFeatures.paidSessions) return;
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from Stripe's form in the browser.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      final status = await _payments.getPayoutStatus();
      if (mounted) setState(() => _status = status);
    } catch (_) {
      // Keep the last known status; the button still works.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openStripe() async {
    setState(() => _busy = true);
    final opened = await _payments.openPayoutSetup();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.payoutOpenFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!MvpFeatures.paidSessions) return const PaymentsDisabledScreen();
    final l10n = context.l10n;
    final status = _status;
    final ready = status?.payoutsEnabled == true;
    final started = status?.connected == true;
    final statusText = ready
        ? l10n.payoutStatusReady
        : started
            ? l10n.payoutStatusPending
            : l10n.payoutStatusNone;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(l10n.payoutTitle),
        backgroundColor: AppColors.canvas,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(l10n.payoutIntro, style: const TextStyle(height: 1.4)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: const Border.fromBorderSide(
                  BorderSide(color: AppColors.border),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    ready
                        ? Icons.check_circle_rounded
                        : Icons.account_balance_outlined,
                    color: ready ? AppColors.primary : AppColors.muted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _busy && status == null
                        ? const LinearProgressIndicator()
                        : Text(statusText,
                            key: const Key('payout_status'),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (!ready)
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  key: const Key('payout_open_stripe'),
                  onPressed: _busy ? null : _openStripe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(started ? l10n.payoutContinue : l10n.payoutStart),
                ),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : _refresh,
              child: Text(l10n.payoutRefresh),
            ),
          ],
        ),
      ),
    );
  }
}
