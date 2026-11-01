import 'package:connect_app/config/legal_texts.dart';
import 'package:connect_app/l10n/l10n.dart';
import 'package:connect_app/models/age_policy.dart';
import 'package:connect_app/screens/settings/settings_screen.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:connect_app/theme/tokens.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

Future<void> _saveDeclaration(bool adult) async {
  final uid = HelperlyTestRuntime.currentUid ?? '';
  if (uid.isEmpty) return;
  await HelperlyTestRuntime.firestore
      .collection('users')
      .doc(uid)
      .set(AgePolicy.declaration(adult: adult), SetOptions(merge: true));
}

/// One-time 18+ confirmation for accounts created before the policy.
/// The app's user-doc stream moves on once the declaration is saved.
class AgeConfirmScreen extends StatefulWidget {
  const AgeConfirmScreen({super.key});

  @override
  State<AgeConfirmScreen> createState() => _AgeConfirmScreenState();
}

class _AgeConfirmScreenState extends State<AgeConfirmScreen> {
  bool _saving = false;

  Future<void> _declare(bool adult) async {
    final l10n = context.l10n;
    if (!adult) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.ageMinorConfirmTitle),
          content: Text(l10n.ageMinorConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              key: const Key('age_minor_confirm'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.ageMinorConfirm),
            ),
          ],
        ),
      );
      if (sure != true) return;
    }
    setState(() => _saving = true);
    try {
      await _saveDeclaration(adult);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.commonSaveFailed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(l10n.ageConfirmTitle,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text(l10n.ageConfirmBody,
                  style: const TextStyle(color: AppColors.muted, height: 1.4)),
              const Spacer(),
              FilledButton(
                key: const Key('age_adult'),
                onPressed: _saving ? null : () => _declare(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(50),
                ),
                child: Text(l10n.ageImAdult),
              ),
              const SizedBox(height: 10),
              TextButton(
                key: const Key('age_minor'),
                onPressed: _saving ? null : () => _declare(false),
                child: Text(l10n.ageImMinor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown to accounts declared under 18. Nothing is deleted automatically;
/// the person can delete the account or contact support, and an operator
/// can lift the restriction after review.
class AgeRestrictedScreen extends StatelessWidget {
  const AgeRestrictedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.lock_outline, size: 48, color: AppColors.muted),
              const SizedBox(height: 16),
              Text(l10n.ageRestrictedTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text(l10n.ageRestrictedBody(LegalTexts.supportEmail),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, height: 1.4)),
              const Spacer(),
              OutlinedButton(
                key: const Key('age_restricted_settings'),
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen())),
                child: Text(l10n.settingsDeleteAccount),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => SettingsScreen.signOut(context),
                child: Text(l10n.settingsLogOut),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
