import 'dart:async';

import 'package:connect_app/services/app_telemetry.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connect_app/config/legal_texts.dart';
import 'package:connect_app/l10n/l10n.dart';
import 'package:connect_app/services/locale_controller.dart';
import 'package:connect_app/screens/settings/legal_screen.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:connect_app/services/notification_service.dart';
import 'package:connect_app/services/safety_service.dart';
import 'package:connect_app/theme/tokens.dart';
import 'package:connect_app/widgets/language_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Account settings: help and safety, legal texts, app language, usage
/// statistics, delete account, log out.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static Future<void> signOut(BuildContext context) async {
    await NotificationService.prepareCurrentUserForSignOut();
    SafetyService.instance.stop();
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true)
        .pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _usageStats = AppTelemetry.usageStatsEnabled;
  bool _crashReports = AppTelemetry.crashReportsEnabled;

  void _open(BuildContext context, String title, String markdown) {
    // The legal texts are English until the French versions are reviewed
    // and approved; say so instead of silently switching language.
    final note = Localizations.localeOf(context).languageCode == 'en'
        ? ''
        : '_${context.l10n.settingsLegalEnglishOnly}_\n\n';
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LegalScreen(title: title, markdown: '$note$markdown'),
    ));
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsDeleteTitle),
        content: Text(l10n.settingsDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonDelete,
                style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final uid = HelperlyTestRuntime.currentUid ?? '';
    if (uid.isEmpty) return;
    // Deleting the profile doc makes the root gate replace this screen
    // (with onboarding) before the call returns, so finish with the root
    // navigator instead of this context.
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    // Release push bindings first: afterwards they would write a push
    // installation back under the deleted account.
    await NotificationService.prepareCurrentUserForSignOut();
    var deletedNow = false;
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('deleteAccount',
              options:
                  HttpsCallableOptions(timeout: const Duration(seconds: 60)))
          .call<Object?>();
      // complete=false: the account is gone but some cleanup is retried
      // later, so the message says "within 30 days" rather than "deleted".
      final data = result.data;
      deletedNow = !(data is Map && data['complete'] == false);
      AppTelemetry.event('account_deleted');
    } catch (_) {
      // Server deletion unavailable: record the request, processed daily.
      try {
        await HelperlyTestRuntime.firestore.collection('users').doc(uid).set({
          'deletionRequestedAt': FieldValue.serverTimestamp(),
          'isHelper': false,
        }, SetOptions(merge: true));
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.settingsDeleteFailed),
          ));
        }
        return;
      }
    }
    // Sign out first: a still signed-in deleted account would otherwise sit
    // in onboarding and could recreate its profile doc.
    SafetyService.instance.stop();
    await FirebaseAuth.instance.signOut();
    if (!rootNavigator.mounted) return;
    unawaited(
        rootNavigator.pushNamedAndRemoveUntil('/login', (route) => false));
    await showDialog<void>(
      context: rootNavigator.context,
      builder: (ctx) => AlertDialog(
        title: Text(deletedNow
            ? l10n.settingsDeletedTitle
            : l10n.settingsDeletionRequestedTitle),
        content: Text(deletedNow
            ? l10n.settingsDeletedBody
            : l10n.settingsDeletionRequestedBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
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

    final l10n = context.l10n;
    final languageName =
        lookupAppLocalizations(LocaleController.instance.effective)
            .languageName;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          section(l10n.settingsSectionPreferences),
          ListTile(
            key: const Key('settings_language'),
            leading: const Icon(Icons.language, color: AppColors.text),
            title: Text(l10n.settingsLanguage),
            subtitle: Text(languageName),
            trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
            onTap: () => showLanguagePicker(context),
          ),
          SwitchListTile(
            key: const Key('settings_usage_stats'),
            secondary:
                const Icon(Icons.insights_outlined, color: AppColors.text),
            title: Text(l10n.settingsUsageStats),
            subtitle: Text(l10n.settingsUsageStatsSubtitle),
            value: _usageStats,
            onChanged: (v) {
              setState(() => _usageStats = v);
              AppTelemetry.setUsageStatsEnabled(v);
            },
          ),
          SwitchListTile(
            key: const Key('settings_crash_reports'),
            secondary:
                const Icon(Icons.bug_report_outlined, color: AppColors.text),
            title: Text(l10n.settingsCrashReports),
            subtitle: Text(l10n.settingsCrashReportsSubtitle),
            value: _crashReports,
            onChanged: (v) {
              setState(() => _crashReports = v);
              AppTelemetry.setCrashReportsEnabled(v);
            },
          ),
          section(l10n.settingsSectionHelp),
          row(Icons.health_and_safety_outlined, l10n.settingsHelpSafety,
              () => _open(context, l10n.settingsHelpSafety, LegalTexts.safety)),
          row(
              Icons.groups_outlined,
              l10n.settingsGuidelines,
              () => _open(
                  context, l10n.settingsGuidelines, LegalTexts.guidelines)),
          section(l10n.settingsSectionLegal),
          row(Icons.description_outlined, l10n.settingsTerms,
              () => _open(context, l10n.settingsTerms, LegalTexts.terms)),
          row(Icons.privacy_tip_outlined, l10n.settingsPrivacy,
              () => _open(context, l10n.settingsPrivacy, LegalTexts.privacy)),
          section(l10n.settingsSectionAccount),
          row(Icons.logout, l10n.settingsLogOut,
              () => SettingsScreen.signOut(context)),
          row(Icons.delete_outline, l10n.settingsDeleteAccount,
              () => _deleteAccount(context),
              color: AppColors.danger),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
