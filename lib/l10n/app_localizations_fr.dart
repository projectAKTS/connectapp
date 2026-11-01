// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get languageName => 'Français';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonOk => 'OK';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonTryAgain => 'Veuillez réessayer.';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsSectionHelp => 'Aide';

  @override
  String get settingsSectionLegal => 'Mentions légales';

  @override
  String get settingsSectionAccount => 'Compte';

  @override
  String get settingsSectionPreferences => 'Préférences';

  @override
  String get settingsHelpSafety => 'Aide et sécurité';

  @override
  String get settingsGuidelines => 'Règles de la communauté';

  @override
  String get settingsTerms => 'Conditions d\'utilisation';

  @override
  String get settingsPrivacy => 'Politique de confidentialité';

  @override
  String get settingsLogOut => 'Se déconnecter';

  @override
  String get settingsDeleteAccount => 'Supprimer le compte';

  @override
  String get settingsDeleteTitle => 'Supprimer votre compte?';

  @override
  String get settingsDeleteBody =>
      'Votre profil, vos publications et vos messages seront supprimés et vous serez déconnecté. Cette action est irréversible.';

  @override
  String get settingsDeleteFailed =>
      'Impossible de supprimer votre compte. Veuillez réessayer.';

  @override
  String get settingsDeletedTitle => 'Compte supprimé';

  @override
  String get settingsDeletedBody =>
      'Votre compte et vos données personnelles ont été supprimés.';

  @override
  String get settingsDeletionRequestedTitle => 'Suppression du compte demandée';

  @override
  String get settingsDeletionRequestedBody =>
      'Votre compte et vos données personnelles seront supprimés d\'ici 30 jours. Vous allez maintenant être déconnecté.';

  @override
  String get settingsLegalEnglishOnly =>
      'Ce document est pour l\'instant offert en anglais seulement.';

  @override
  String get settingsLanguage => 'Langue de l\'application';

  @override
  String get languageSystemDefault => 'Langue de l\'appareil';

  @override
  String languageSystemDefaultSubtitle(String language) {
    return 'Actuellement : $language';
  }

  @override
  String get languagePickerTitle => 'Langue de l\'application';

  @override
  String get languagePickerNote =>
      'Ce choix ne change que les textes de l\'application. Les langues que vous parlez se règlent dans votre profil.';

  @override
  String get settingsUsageStats => 'Partager les statistiques d\'utilisation';

  @override
  String get settingsUsageStatsSubtitle =>
      'Les écrans et fonctions utilisés, pour nous aider à améliorer Helperly. N\'inclut jamais vos messages ni vos publications. Désactivé sauf si vous l\'activez.';
}
