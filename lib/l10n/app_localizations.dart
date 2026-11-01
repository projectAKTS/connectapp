import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr')
  ];

  /// This language's own name, shown in the language picker.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageName;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Please try again.'**
  String get commonTryAgain;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionHelp.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get settingsSectionHelp;

  /// No description provided for @settingsSectionLegal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get settingsSectionLegal;

  /// No description provided for @settingsSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsSectionAccount;

  /// No description provided for @settingsSectionPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsSectionPreferences;

  /// No description provided for @settingsHelpSafety.
  ///
  /// In en, this message translates to:
  /// **'Help & safety'**
  String get settingsHelpSafety;

  /// No description provided for @settingsGuidelines.
  ///
  /// In en, this message translates to:
  /// **'Community guidelines'**
  String get settingsGuidelines;

  /// No description provided for @settingsTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get settingsTerms;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacy;

  /// No description provided for @settingsLogOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsLogOut;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccount;

  /// No description provided for @settingsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get settingsDeleteTitle;

  /// No description provided for @settingsDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Your profile, posts and messages will be deleted and you will be signed out. This can\'t be undone.'**
  String get settingsDeleteBody;

  /// No description provided for @settingsDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete your account. Please try again.'**
  String get settingsDeleteFailed;

  /// No description provided for @settingsDeletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Account deleted'**
  String get settingsDeletedTitle;

  /// No description provided for @settingsDeletedBody.
  ///
  /// In en, this message translates to:
  /// **'Your account and personal data have been deleted.'**
  String get settingsDeletedBody;

  /// No description provided for @settingsDeletionRequestedTitle.
  ///
  /// In en, this message translates to:
  /// **'Account deletion requested'**
  String get settingsDeletionRequestedTitle;

  /// No description provided for @settingsDeletionRequestedBody.
  ///
  /// In en, this message translates to:
  /// **'Your account and personal data will be deleted within 30 days. You will now be signed out.'**
  String get settingsDeletionRequestedBody;

  /// No description provided for @settingsLegalEnglishOnly.
  ///
  /// In en, this message translates to:
  /// **'This document is currently available in English only.'**
  String get settingsLegalEnglishOnly;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get settingsLanguage;

  /// No description provided for @languageSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'Device language'**
  String get languageSystemDefault;

  /// No description provided for @languageSystemDefaultSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Currently {language}'**
  String languageSystemDefaultSubtitle(String language);

  /// No description provided for @languagePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get languagePickerTitle;

  /// No description provided for @languagePickerNote.
  ///
  /// In en, this message translates to:
  /// **'This only changes the app\'s text. The languages you speak are set in your profile.'**
  String get languagePickerNote;

  /// No description provided for @settingsUsageStats.
  ///
  /// In en, this message translates to:
  /// **'Share usage statistics'**
  String get settingsUsageStats;

  /// No description provided for @settingsUsageStatsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Which screens and features are used, to help us improve Helperly. Never includes your messages or posts. Off unless you turn it on.'**
  String get settingsUsageStatsSubtitle;

  /// No description provided for @topicMovingToCanada.
  ///
  /// In en, this message translates to:
  /// **'Moving to Canada'**
  String get topicMovingToCanada;

  /// No description provided for @topicHousing.
  ///
  /// In en, this message translates to:
  /// **'Housing'**
  String get topicHousing;

  /// No description provided for @topicJobHunting.
  ///
  /// In en, this message translates to:
  /// **'Job hunting'**
  String get topicJobHunting;

  /// No description provided for @topicStudentLife.
  ///
  /// In en, this message translates to:
  /// **'Student life'**
  String get topicStudentLife;

  /// No description provided for @topicDailyLife.
  ///
  /// In en, this message translates to:
  /// **'Daily life in Canada'**
  String get topicDailyLife;

  /// No description provided for @topicLanguageLearning.
  ///
  /// In en, this message translates to:
  /// **'Language learning'**
  String get topicLanguageLearning;

  /// No description provided for @topicParenting.
  ///
  /// In en, this message translates to:
  /// **'Parenting support'**
  String get topicParenting;

  /// No description provided for @topicQuebec.
  ///
  /// In en, this message translates to:
  /// **'Quebec-specific help'**
  String get topicQuebec;

  /// No description provided for @topicImmigrationExperience.
  ///
  /// In en, this message translates to:
  /// **'Immigration experience'**
  String get topicImmigrationExperience;

  /// No description provided for @expertiseResume.
  ///
  /// In en, this message translates to:
  /// **'Resume review'**
  String get expertiseResume;

  /// No description provided for @expertiseInterview.
  ///
  /// In en, this message translates to:
  /// **'Interview prep'**
  String get expertiseInterview;

  /// No description provided for @expertiseCareer.
  ///
  /// In en, this message translates to:
  /// **'Career transitions'**
  String get expertiseCareer;

  /// No description provided for @expertiseHousingSearch.
  ///
  /// In en, this message translates to:
  /// **'Housing search'**
  String get expertiseHousingSearch;

  /// No description provided for @expertiseSchool.
  ///
  /// In en, this message translates to:
  /// **'School applications'**
  String get expertiseSchool;

  /// No description provided for @expertiseLanguagePractice.
  ///
  /// In en, this message translates to:
  /// **'Language practice'**
  String get expertiseLanguagePractice;

  /// No description provided for @expertiseSettlement.
  ///
  /// In en, this message translates to:
  /// **'Settlement tips'**
  String get expertiseSettlement;

  /// No description provided for @countryCanada.
  ///
  /// In en, this message translates to:
  /// **'Canada'**
  String get countryCanada;

  /// No description provided for @countryUsa.
  ///
  /// In en, this message translates to:
  /// **'USA'**
  String get countryUsa;

  /// No description provided for @countryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get countryOther;

  /// No description provided for @langEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEn;

  /// No description provided for @langFr.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get langFr;

  /// No description provided for @langAr.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get langAr;

  /// No description provided for @langEs.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get langEs;

  /// No description provided for @langPt.
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get langPt;

  /// No description provided for @langZh.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get langZh;

  /// No description provided for @langHi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get langHi;

  /// No description provided for @langPa.
  ///
  /// In en, this message translates to:
  /// **'Punjabi'**
  String get langPa;

  /// No description provided for @langUr.
  ///
  /// In en, this message translates to:
  /// **'Urdu'**
  String get langUr;

  /// No description provided for @langFa.
  ///
  /// In en, this message translates to:
  /// **'Persian'**
  String get langFa;

  /// No description provided for @langTr.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get langTr;

  /// No description provided for @langRu.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get langRu;

  /// No description provided for @langUk.
  ///
  /// In en, this message translates to:
  /// **'Ukrainian'**
  String get langUk;

  /// No description provided for @langTl.
  ///
  /// In en, this message translates to:
  /// **'Tagalog'**
  String get langTl;

  /// No description provided for @langVi.
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get langVi;

  /// No description provided for @langKo.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get langKo;

  /// No description provided for @langIt.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get langIt;

  /// No description provided for @langDe.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get langDe;

  /// No description provided for @langRo.
  ///
  /// In en, this message translates to:
  /// **'Romanian'**
  String get langRo;

  /// No description provided for @langBn.
  ///
  /// In en, this message translates to:
  /// **'Bengali'**
  String get langBn;

  /// No description provided for @langHt.
  ///
  /// In en, this message translates to:
  /// **'Haitian Creole'**
  String get langHt;

  /// No description provided for @langOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get langOther;

  /// No description provided for @reportSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam or scam'**
  String get reportSpam;

  /// No description provided for @reportHarassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment or hate'**
  String get reportHarassment;

  /// No description provided for @reportInappropriate.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate content'**
  String get reportInappropriate;

  /// No description provided for @reportHarmfulAdvice.
  ///
  /// In en, this message translates to:
  /// **'Harmful or misleading advice'**
  String get reportHarmfulAdvice;

  /// No description provided for @reportImpersonation.
  ///
  /// In en, this message translates to:
  /// **'Pretending to be someone else'**
  String get reportImpersonation;

  /// No description provided for @reportOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get reportOther;

  /// No description provided for @reportSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Why are you reporting this?'**
  String get reportSheetTitle;

  /// No description provided for @reportSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reports are private. Our team reviews them.'**
  String get reportSheetSubtitle;

  /// No description provided for @reportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send the report. Please try again.'**
  String get reportFailed;

  /// No description provided for @reportSent.
  ///
  /// In en, this message translates to:
  /// **'Thanks. We received your report.'**
  String get reportSent;

  /// No description provided for @blockTitle.
  ///
  /// In en, this message translates to:
  /// **'Block {name}?'**
  String blockTitle(String name);

  /// No description provided for @blockBody.
  ///
  /// In en, this message translates to:
  /// **'You won\'t see their posts or messages, and they won\'t appear in your helper list. You can unblock them from their profile.'**
  String get blockBody;

  /// No description provided for @blockAction.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get blockAction;

  /// No description provided for @blockDone.
  ///
  /// In en, this message translates to:
  /// **'{name} is blocked.'**
  String blockDone(String name);

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @spokenLanguagesLabel.
  ///
  /// In en, this message translates to:
  /// **'Languages you speak'**
  String get spokenLanguagesLabel;

  /// No description provided for @spokenLanguagesHint.
  ///
  /// In en, this message translates to:
  /// **'Select languages'**
  String get spokenLanguagesHint;

  /// No description provided for @spokenLanguagesNote.
  ///
  /// In en, this message translates to:
  /// **'People can find helpers who speak their language. This is separate from the app\'s language.'**
  String get spokenLanguagesNote;

  /// No description provided for @spokenLanguagesRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one language you speak.'**
  String get spokenLanguagesRequired;

  /// No description provided for @commonApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get commonApply;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results.'**
  String get commonNoResults;

  /// No description provided for @findHelperTitle.
  ///
  /// In en, this message translates to:
  /// **'Find a helper'**
  String get findHelperTitle;

  /// No description provided for @findHelperResetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get findHelperResetFilters;

  /// No description provided for @findHelperSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search helpers…'**
  String get findHelperSearchHint;

  /// No description provided for @findHelperNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No helpers match your filters.'**
  String get findHelperNoMatches;

  /// No description provided for @findHelperAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get findHelperAvailable;

  /// No description provided for @filterCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get filterCategory;

  /// No description provided for @filterCategoryCount.
  ///
  /// In en, this message translates to:
  /// **'Category ({count})'**
  String filterCategoryCount(int count);

  /// No description provided for @filterSelectCategories.
  ///
  /// In en, this message translates to:
  /// **'Select categories'**
  String get filterSelectCategories;

  /// No description provided for @filterLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get filterLanguage;

  /// No description provided for @filterLanguageCount.
  ///
  /// In en, this message translates to:
  /// **'Language ({count})'**
  String filterLanguageCount(int count);

  /// No description provided for @filterSelectLanguages.
  ///
  /// In en, this message translates to:
  /// **'Select languages'**
  String get filterSelectLanguages;

  /// No description provided for @filterVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get filterVerified;

  /// No description provided for @filterPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get filterPrice;

  /// No description provided for @filterPriceMin.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get filterPriceMin;

  /// No description provided for @filterPriceMax.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get filterPriceMax;

  /// No description provided for @sortRelevance.
  ///
  /// In en, this message translates to:
  /// **'Relevance'**
  String get sortRelevance;

  /// No description provided for @sortRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get sortRating;

  /// No description provided for @sortPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get sortPrice;

  /// No description provided for @sortPriceLowHigh.
  ///
  /// In en, this message translates to:
  /// **'Price (low → high)'**
  String get sortPriceLowHigh;

  /// No description provided for @sortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get sortNewest;

  /// No description provided for @pricePerHour.
  ///
  /// In en, this message translates to:
  /// **'{amount}/hr'**
  String pricePerHour(String amount);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
