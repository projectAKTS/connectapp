import 'dart:ui';

import 'package:connect_app/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';

export 'package:connect_app/l10n/app_localizations.dart';

/// App languages. English is the fallback for every other device language.
class AppLanguages {
  AppLanguages._();

  static const Locale fallback = Locale('en');

  static const List<Locale> supported = AppLocalizations.supportedLocales;

  /// The supported language for a device locale ('fr_CA' -> 'fr',
  /// 'tr_TR' -> 'en').
  static Locale resolve(Locale? device) {
    final code = device?.languageCode;
    for (final l in supported) {
      if (l.languageCode == code) return l;
    }
    return fallback;
  }

  /// The locale used for dates and numbers: the app language with the
  /// device's region when there is one ('fr' on a fr_CA or en_CA device ->
  /// 'fr_CA'), so Canadian users get "4,99 $" and 24-hour times in French.
  static String formatLocale(Locale appLocale, [Locale? device]) {
    final region = (device ?? PlatformDispatcher.instance.locale).countryCode;
    if (region == null || region.isEmpty) return appLocale.languageCode;
    return '${appLocale.languageCode}_$region';
  }
}

extension L10nContext on BuildContext {
  /// The app's strings. Falls back to English where no localization
  /// delegate is installed (isolated widget tests, overlays above the app).
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      lookupAppLocalizations(AppLanguages.fallback);
}
