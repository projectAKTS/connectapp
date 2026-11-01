import 'dart:async';

import 'package:connect_app/l10n/l10n.dart';
import 'package:connect_app/services/app_prefs.dart';
import 'package:connect_app/services/app_telemetry.dart';
import 'package:connect_app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Asks once, without blocking, whether the person wants to share crash
/// reports and usage statistics: two separate choices, both off. Shown
/// once per device (dismissing counts as "no"); Settings can change both
/// later.
class TelemetryConsentPrompt extends StatefulWidget {
  final Widget child;
  const TelemetryConsentPrompt({super.key, required this.child});

  static const String shownPrefKey = 'telemetryPromptShown';

  @override
  State<TelemetryConsentPrompt> createState() => _TelemetryConsentPromptState();
}

class _TelemetryConsentPromptState extends State<TelemetryConsentPrompt> {
  @override
  void initState() {
    super.initState();
    if (AppPrefs.getBool(TelemetryConsentPrompt.shownPrefKey) == true) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _show());
  }

  Future<void> _show() async {
    if (!mounted) return;
    // Marked before showing, so a dismissal or a crash never re-asks.
    unawaited(AppPrefs.set(TelemetryConsentPrompt.shownPrefKey, true));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.canvas,
      showDragHandle: true,
      builder: (_) => const _ConsentSheet(),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ConsentSheet extends StatefulWidget {
  const _ConsentSheet();

  @override
  State<_ConsentSheet> createState() => _ConsentSheetState();
}

class _ConsentSheetState extends State<_ConsentSheet> {
  bool _crash = AppTelemetry.crashReportsEnabled;
  bool _usage = AppTelemetry.usageStatsEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.consentTitle,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(l10n.consentBody,
                style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const Key('consent_crash'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.settingsCrashReports),
              subtitle: Text(l10n.settingsCrashReportsSubtitle),
              value: _crash,
              onChanged: (v) {
                setState(() => _crash = v);
                AppTelemetry.setCrashReportsEnabled(v);
              },
            ),
            SwitchListTile(
              key: const Key('consent_usage'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.settingsUsageStats),
              subtitle: Text(l10n.settingsUsageStatsSubtitle),
              value: _usage,
              onChanged: (v) {
                setState(() => _usage = v);
                AppTelemetry.setUsageStatsEnabled(v);
              },
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('consent_done'),
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(l10n.commonDone),
            ),
          ],
        ),
      ),
    );
  }
}
