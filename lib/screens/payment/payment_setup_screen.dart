// lib/screens/payment/payment_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:connect_app/theme/tokens.dart';
import 'package:connect_app/services/payment_service.dart';

class PaymentSetupScreen extends StatefulWidget {
  const PaymentSetupScreen({super.key});

  @override
  State<PaymentSetupScreen> createState() => _PaymentSetupScreenState();
}

class _PaymentSetupScreenState extends State<PaymentSetupScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _onAddCard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await PaymentService.instance.setupPaymentMethod();

    if (!mounted) return;

    setState(() => _loading = false);

    switch (result) {
      case PaymentResult.success:
        Navigator.pop(context);
        break;

      case PaymentResult.blocked:
        setState(() {
          _error =
              'Payments are temporarily unavailable (App Check blocked).\n\n'
              'This usually means App Attest/DeviceCheck failed for this build.\n'
              'Check Firebase App Check settings or enable debug tokens for dev.';
        });
        break;

      default:
        setState(() => _error = 'Could not add card. Please try again.');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Payment method'),
        backgroundColor: AppColors.canvas,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            children: [
              _card(
                child: Row(
                  children: const [
                    Icon(Icons.credit_card, color: AppColors.muted),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Add a card for consultations & credits.\nYou can change it anytime in Settings.',
                        style: TextStyle(color: AppColors.text),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_error != null)
                _card(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.orange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.text),
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _onAddCard,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F4C46),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add / Update card'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );
}
