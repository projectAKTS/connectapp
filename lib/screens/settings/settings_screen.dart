import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connect_app/config/legal_texts.dart';
import 'package:connect_app/screens/settings/legal_screen.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:connect_app/services/notification_service.dart';
import 'package:connect_app/services/safety_service.dart';
import 'package:connect_app/theme/tokens.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Account settings: help and safety, legal texts, delete account, log out.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static Future<void> signOut(BuildContext context,
      {bool pushAlreadyReleased = false}) async {
    if (!pushAlreadyReleased) {
      await NotificationService.prepareCurrentUserForSignOut();
    }
    SafetyService.instance.stop();
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true)
        .pushNamedAndRemoveUntil('/login', (route) => false);
  }

  void _open(BuildContext context, String title, String markdown) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LegalScreen(title: title, markdown: markdown),
    ));
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'Your profile, posts and messages will be deleted and you will be '
          "signed out. This can't be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final uid = HelperlyTestRuntime.currentUid ?? '';
    if (uid.isEmpty) return;
    // Release push bindings first: afterwards they would write a push
    // installation back under the deleted account.
    await NotificationService.prepareCurrentUserForSignOut();
    var deletedNow = false;
    try {
      await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('deleteAccount',
              options:
                  HttpsCallableOptions(timeout: const Duration(seconds: 60)))
          .call<void>();
      deletedNow = true;
    } catch (_) {
      // Server deletion unavailable: record the request, processed daily.
      try {
        await HelperlyTestRuntime.firestore.collection('users').doc(uid).set({
          'deletionRequestedAt': FieldValue.serverTimestamp(),
          'isHelper': false,
        }, SetOptions(merge: true));
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not delete your account. Please try again.'),
          ));
        }
        return;
      }
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            Text(deletedNow ? 'Account deleted' : 'Account deletion requested'),
        content: Text(deletedNow
            ? 'Your account and personal data have been deleted.'
            : 'Your account and personal data will be deleted within 30 '
                'days. You will now be signed out.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (context.mounted) await signOut(context, pushAlreadyReleased: true);
  }

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String title, VoidCallback onTap,
        {Color color = AppColors.text}) {
      return ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(color: color)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
        onTap: onTap,
      );
    }

    Widget section(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
          child: Text(title,
              style: const TextStyle(
                  color: AppColors.muted, fontWeight: FontWeight.w600)),
        );

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          section('Help'),
          row(Icons.health_and_safety_outlined, 'Help & safety',
              () => _open(context, 'Help & safety', LegalTexts.safety)),
          row(
              Icons.groups_outlined,
              'Community guidelines',
              () => _open(
                  context, 'Community guidelines', LegalTexts.guidelines)),
          section('Legal'),
          row(Icons.description_outlined, 'Terms of Use',
              () => _open(context, 'Terms of Use', LegalTexts.terms)),
          row(Icons.privacy_tip_outlined, 'Privacy Policy',
              () => _open(context, 'Privacy Policy', LegalTexts.privacy)),
          section('Account'),
          row(Icons.logout, 'Log out', () => signOut(context)),
          row(Icons.delete_outline, 'Delete account',
              () => _deleteAccount(context),
              color: AppColors.danger),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
