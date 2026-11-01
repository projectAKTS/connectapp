// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageName => 'English';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonSave => 'Save';

  @override
  String get commonTryAgain => 'Please try again.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionHelp => 'Help';

  @override
  String get settingsSectionLegal => 'Legal';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsSectionPreferences => 'Preferences';

  @override
  String get settingsHelpSafety => 'Help & safety';

  @override
  String get settingsGuidelines => 'Community guidelines';

  @override
  String get settingsTerms => 'Terms of Use';

  @override
  String get settingsPrivacy => 'Privacy Policy';

  @override
  String get settingsLogOut => 'Log out';

  @override
  String get settingsDeleteAccount => 'Delete account';

  @override
  String get settingsDeleteTitle => 'Delete your account?';

  @override
  String get settingsDeleteBody =>
      'Your profile, posts and messages will be deleted and you will be signed out. This can\'t be undone.';

  @override
  String get settingsDeleteFailed =>
      'Could not delete your account. Please try again.';

  @override
  String get settingsDeletedTitle => 'Account deleted';

  @override
  String get settingsDeletedBody =>
      'Your account and personal data have been deleted.';

  @override
  String get settingsDeletionRequestedTitle => 'Account deletion requested';

  @override
  String get settingsDeletionRequestedBody =>
      'Your account and personal data will be deleted within 30 days. You will now be signed out.';

  @override
  String get settingsLegalEnglishOnly =>
      'This document is currently available in English only.';

  @override
  String get settingsLanguage => 'App language';

  @override
  String get languageSystemDefault => 'Device language';

  @override
  String languageSystemDefaultSubtitle(String language) {
    return 'Currently $language';
  }

  @override
  String get languagePickerTitle => 'App language';

  @override
  String get languagePickerNote =>
      'This only changes the app\'s text. The languages you speak are set in your profile.';

  @override
  String get settingsUsageStats => 'Share usage statistics';

  @override
  String get settingsUsageStatsSubtitle =>
      'Which screens and features are used, to help us improve Helperly. Never includes your messages or posts. Off unless you turn it on.';
}
