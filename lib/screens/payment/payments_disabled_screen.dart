import 'package:connect_app/l10n/l10n.dart';
import 'package:connect_app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Shown if an obsolete route or direct navigation tries to open payments.
class PaymentsDisabledScreen extends StatelessWidget {
  const PaymentsDisabledScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: Text(l10n.paymentsUnavailableTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.paymentsUnavailableBody,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, height: 1.45),
          ),
        ),
      ),
    );
  }
}
