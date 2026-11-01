import 'dart:async';

import 'package:connect_app/l10n/l10n.dart';
import 'package:connect_app/services/app_prefs.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:flutter/widgets.dart';

/// The app's interface language: the device language by default, or the
/// user's choice in Settings. Separate from the languages a user speaks
/// (`spokenLanguages` on the profile).
///
/// The choice is saved on the device. The effective language is mirrored to
/// `users/{uid}.appLocale` only so the server can write push notifications
/// in that language.
class LocaleController {
  LocaleController._();

  static final LocaleController instance = LocaleController._();

  static const String prefKey = 'appLocale';

  /// The chosen locale, or null to follow the device.
  final ValueNotifier<Locale?> choice = ValueNotifier<Locale?>(null);

  /// Applies the saved choice. Call after [AppPrefs.load].
  void loadSaved() {
    final saved = AppPrefs.getString(prefKey);
    choice.value = saved == null ? null : _supportedOrNull(saved);
  }

  Locale? _supportedOrNull(String code) {
    for (final l in AppLanguages.supported) {
      if (l.languageCode == code) return l;
    }
    return null;
  }

  /// The language the app is shown in right now.
  Locale get effective =>
      choice.value ??
      AppLanguages.resolve(WidgetsBinding.instance.platformDispatcher.locale);

  /// Saves [locale] (null = follow the device) and tells the server.
  Future<void> select(Locale? locale) async {
    choice.value = locale;
    await AppPrefs.set(prefKey, locale?.languageCode);
    unawaited(syncToAccount());
  }

  /// Writes the effective language to the signed-in user's doc when it
  /// differs from [known] (the value already on the doc, if read).
  Future<void> syncToAccount({String? known}) async {
    final code = effective.languageCode;
    if (code == known) return;
    try {
      final uid = HelperlyTestRuntime.currentUid ?? '';
      if (uid.isEmpty) return;
      await HelperlyTestRuntime.firestore
          .collection('users')
          .doc(uid)
          .update({'appLocale': code});
    } catch (_) {
      // Offline or no doc yet; the next sign-in writes it.
    }
  }
}
