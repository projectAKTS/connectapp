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

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get tabSearch;

  /// No description provided for @tabPost.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get tabPost;

  /// No description provided for @tabProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabProfile;

  /// No description provided for @adviceNotice.
  ///
  /// In en, this message translates to:
  /// **'Helpers share personal experience. This is not legal, immigration or medical advice.'**
  String get adviceNotice;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authEmailHint.
  ///
  /// In en, this message translates to:
  /// **'name@example.com'**
  String get authEmailHint;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get authOr;

  /// No description provided for @loginWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginWelcomeBack;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get loginSubtitle;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get loginButton;

  /// No description provided for @loginForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get loginForgotPassword;

  /// No description provided for @loginContinueGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get loginContinueGoogle;

  /// No description provided for @loginContinueApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get loginContinueApple;

  /// No description provided for @loginNewHere.
  ///
  /// In en, this message translates to:
  /// **'New here?'**
  String get loginNewHere;

  /// No description provided for @loginCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get loginCreateAccount;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please try again.'**
  String get loginFailed;

  /// No description provided for @loginCheckCredentials.
  ///
  /// In en, this message translates to:
  /// **'Could not log in. Check your email and password.'**
  String get loginCheckCredentials;

  /// No description provided for @googleCancelled.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in was cancelled.'**
  String get googleCancelled;

  /// No description provided for @googleTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in timed out. Please try again.'**
  String get googleTimedOut;

  /// No description provided for @googleFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed. Please try again.'**
  String get googleFailed;

  /// No description provided for @appleOnlyApple.
  ///
  /// In en, this message translates to:
  /// **'Apple Sign-In is only available on Apple devices.'**
  String get appleOnlyApple;

  /// No description provided for @appleCancelled.
  ///
  /// In en, this message translates to:
  /// **'Apple sign-in was cancelled.'**
  String get appleCancelled;

  /// No description provided for @appleTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Apple sign-in timed out. Please try again.'**
  String get appleTimedOut;

  /// No description provided for @appleFailed.
  ///
  /// In en, this message translates to:
  /// **'Apple sign-in failed. Please try again.'**
  String get appleFailed;

  /// No description provided for @signupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get signupTitle;

  /// No description provided for @signupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join the community and start connecting.'**
  String get signupSubtitle;

  /// No description provided for @signupFirstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get signupFirstName;

  /// No description provided for @signupLastNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Last name (optional)'**
  String get signupLastNameOptional;

  /// No description provided for @signupLastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get signupLastName;

  /// No description provided for @signupEmailHint.
  ///
  /// In en, this message translates to:
  /// **'you@domain.com'**
  String get signupEmailHint;

  /// No description provided for @signupPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Min 8 characters'**
  String get signupPasswordHint;

  /// No description provided for @signupConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get signupConfirmPassword;

  /// No description provided for @signupRepeatPassword.
  ///
  /// In en, this message translates to:
  /// **'Repeat password'**
  String get signupRepeatPassword;

  /// No description provided for @signupButton.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get signupButton;

  /// No description provided for @signupWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign up with Google'**
  String get signupWithGoogle;

  /// No description provided for @signupWithApple.
  ///
  /// In en, this message translates to:
  /// **'Sign up with Apple'**
  String get signupWithApple;

  /// No description provided for @signupHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Log in'**
  String get signupHaveAccount;

  /// No description provided for @signupAgree.
  ///
  /// In en, this message translates to:
  /// **'By creating an account, you agree to our'**
  String get signupAgree;

  /// No description provided for @signupAnd.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get signupAnd;

  /// No description provided for @signupFirstNameRequired.
  ///
  /// In en, this message translates to:
  /// **'First name is required'**
  String get signupFirstNameRequired;

  /// No description provided for @signupEmailPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Email and password are required'**
  String get signupEmailPasswordRequired;

  /// No description provided for @signupPasswordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get signupPasswordsDontMatch;

  /// No description provided for @signupRegistered.
  ///
  /// In en, this message translates to:
  /// **'Registered! Let’s finish onboarding.'**
  String get signupRegistered;

  /// No description provided for @signupEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'That email is already registered.'**
  String get signupEmailInUse;

  /// No description provided for @signupInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address.'**
  String get signupInvalidEmail;

  /// No description provided for @signupWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Password is too weak.'**
  String get signupWeakPassword;

  /// No description provided for @signupFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed. Please try again.'**
  String get signupFailed;

  /// No description provided for @resetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetTitle;

  /// No description provided for @resetHeading.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get resetHeading;

  /// No description provided for @resetBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the email you used to create your account. We’ll send you a link to reset your password.'**
  String get resetBody;

  /// No description provided for @resetSend.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get resetSend;

  /// No description provided for @resetEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email.'**
  String get resetEnterEmail;

  /// No description provided for @resetSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent to {email}'**
  String resetSent(String email);

  /// No description provided for @resetTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Request timed out. Try again.'**
  String get resetTimedOut;

  /// No description provided for @resetFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send the reset email. Please try again.'**
  String get resetFailed;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get commonFinish;

  /// No description provided for @commonRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get commonRequired;

  /// No description provided for @commonNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get commonNotSet;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get commonLoadMore;

  /// No description provided for @commonShowMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get commonShowMore;

  /// No description provided for @commonShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get commonShowLess;

  /// No description provided for @commonTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get commonTakePhoto;

  /// No description provided for @commonChooseFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Choose from library'**
  String get commonChooseFromLibrary;

  /// No description provided for @commonSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t save right now. Please try again.'**
  String get commonSaveFailed;

  /// No description provided for @commonSavedLocally.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device. It will sync later.'**
  String get commonSavedLocally;

  /// No description provided for @commonPhotoUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t upload the photo. Please try again.'**
  String get commonPhotoUploadFailed;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Onboarding'**
  String get onboardingTitle;

  /// No description provided for @onboardingProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile basics'**
  String get onboardingProfileTitle;

  /// No description provided for @onboardingProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add basics so we can personalize your experience.'**
  String get onboardingProfileSubtitle;

  /// No description provided for @onboardingDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get onboardingDisplayName;

  /// No description provided for @onboardingYourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get onboardingYourName;

  /// No description provided for @onboardingCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get onboardingCity;

  /// No description provided for @onboardingCityHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Montreal'**
  String get onboardingCityHint;

  /// No description provided for @onboardingTimeZone.
  ///
  /// In en, this message translates to:
  /// **'Time zone'**
  String get onboardingTimeZone;

  /// No description provided for @onboardingTimeZoneHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. GMT-5'**
  String get onboardingTimeZoneHint;

  /// No description provided for @onboardingCountry.
  ///
  /// In en, this message translates to:
  /// **'Country of residence'**
  String get onboardingCountry;

  /// No description provided for @onboardingSelectCountry.
  ///
  /// In en, this message translates to:
  /// **'Select country'**
  String get onboardingSelectCountry;

  /// No description provided for @onboardingHowUse.
  ///
  /// In en, this message translates to:
  /// **'How will you use Helperly?'**
  String get onboardingHowUse;

  /// No description provided for @roleSeeker.
  ///
  /// In en, this message translates to:
  /// **'I’m here to get help'**
  String get roleSeeker;

  /// No description provided for @roleHelper.
  ///
  /// In en, this message translates to:
  /// **'I’m here to give help'**
  String get roleHelper;

  /// No description provided for @roleBoth.
  ///
  /// In en, this message translates to:
  /// **'I’m open to both'**
  String get roleBoth;

  /// No description provided for @onboardingHelperTitle.
  ///
  /// In en, this message translates to:
  /// **'Helper setup'**
  String get onboardingHelperTitle;

  /// No description provided for @onboardingHelperSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set your preferred support mode and availability.'**
  String get onboardingHelperSubtitle;

  /// No description provided for @onboardingExpertise.
  ///
  /// In en, this message translates to:
  /// **'Areas of expertise'**
  String get onboardingExpertise;

  /// No description provided for @onboardingPreferredMode.
  ///
  /// In en, this message translates to:
  /// **'Preferred mode'**
  String get onboardingPreferredMode;

  /// No description provided for @modeChat.
  ///
  /// In en, this message translates to:
  /// **'CHAT'**
  String get modeChat;

  /// No description provided for @modeCall.
  ///
  /// In en, this message translates to:
  /// **'CALL'**
  String get modeCall;

  /// No description provided for @modeVideo.
  ///
  /// In en, this message translates to:
  /// **'VIDEO'**
  String get modeVideo;

  /// No description provided for @onboardingAvailability.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get onboardingAvailability;

  /// No description provided for @onboardingTopicsTitle.
  ///
  /// In en, this message translates to:
  /// **'Topics'**
  String get onboardingTopicsTitle;

  /// No description provided for @onboardingTopicsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick what you need help with or can help others with.'**
  String get onboardingTopicsSubtitle;

  /// No description provided for @onboardingPickTopics.
  ///
  /// In en, this message translates to:
  /// **'Pick a few topics'**
  String get onboardingPickTopics;

  /// No description provided for @onboardingPickOneTopic.
  ///
  /// In en, this message translates to:
  /// **'Pick at least one topic.'**
  String get onboardingPickOneTopic;

  /// No description provided for @timeNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get timeNow;

  /// No description provided for @timeAgoSeconds.
  ///
  /// In en, this message translates to:
  /// **'{n}s ago'**
  String timeAgoSeconds(int n);

  /// No description provided for @timeAgoMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n}m ago'**
  String timeAgoMinutes(int n);

  /// No description provided for @timeAgoHours.
  ///
  /// In en, this message translates to:
  /// **'{n}h ago'**
  String timeAgoHours(int n);

  /// No description provided for @timeAgoDays.
  ///
  /// In en, this message translates to:
  /// **'{n}d ago'**
  String timeAgoDays(int n);

  /// No description provided for @timeAgoWeeks.
  ///
  /// In en, this message translates to:
  /// **'{n}w ago'**
  String timeAgoWeeks(int n);

  /// No description provided for @timeAgoMonths.
  ///
  /// In en, this message translates to:
  /// **'{n}mo ago'**
  String timeAgoMonths(int n);

  /// No description provided for @timeAgoYears.
  ///
  /// In en, this message translates to:
  /// **'{n}y ago'**
  String timeAgoYears(int n);

  /// No description provided for @postTypeQuick.
  ///
  /// In en, this message translates to:
  /// **'Quick Post'**
  String get postTypeQuick;

  /// No description provided for @postTypeExperience.
  ///
  /// In en, this message translates to:
  /// **'Experience Post'**
  String get postTypeExperience;

  /// No description provided for @postTypeAdvice.
  ///
  /// In en, this message translates to:
  /// **'Advice Request Post'**
  String get postTypeAdvice;

  /// No description provided for @postTypeHowTo.
  ///
  /// In en, this message translates to:
  /// **'How-To Guide Post'**
  String get postTypeHowTo;

  /// No description provided for @postTypeLessons.
  ///
  /// In en, this message translates to:
  /// **'Lessons Learned Post'**
  String get postTypeLessons;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTitle;

  /// No description provided for @homeMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get homeMessages;

  /// No description provided for @homeWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}'**
  String homeWelcome(String name);

  /// No description provided for @homeWelcomeThere.
  ///
  /// In en, this message translates to:
  /// **'there'**
  String get homeWelcomeThere;

  /// No description provided for @homeMyConnections.
  ///
  /// In en, this message translates to:
  /// **'My connections'**
  String get homeMyConnections;

  /// No description provided for @homeRecentPosts.
  ///
  /// In en, this message translates to:
  /// **'Recent posts'**
  String get homeRecentPosts;

  /// No description provided for @homeLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load posts right now.'**
  String get homeLoadFailed;

  /// No description provided for @homeNoPosts.
  ///
  /// In en, this message translates to:
  /// **'No posts yet! Create one to get started.'**
  String get homeNoPosts;

  /// No description provided for @homePostingInBackground.
  ///
  /// In en, this message translates to:
  /// **'Posting in background…'**
  String get homePostingInBackground;

  /// No description provided for @postDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete post?'**
  String get postDeleteTitle;

  /// No description provided for @postDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get postDeleteBody;

  /// No description provided for @postOptions.
  ///
  /// In en, this message translates to:
  /// **'Post options'**
  String get postOptions;

  /// No description provided for @postReport.
  ///
  /// In en, this message translates to:
  /// **'Report post'**
  String get postReport;

  /// No description provided for @postBlockAuthor.
  ///
  /// In en, this message translates to:
  /// **'Block {name}'**
  String postBlockAuthor(String name);

  /// No description provided for @postHelpful.
  ///
  /// In en, this message translates to:
  /// **'Helpful'**
  String get postHelpful;

  /// No description provided for @actionConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get actionConnect;

  /// No description provided for @actionViewProfile.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get actionViewProfile;

  /// No description provided for @actionBookCall.
  ///
  /// In en, this message translates to:
  /// **'Book a call'**
  String get actionBookCall;

  /// No description provided for @actionMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get actionMessage;

  /// No description provided for @actionAudioCall.
  ///
  /// In en, this message translates to:
  /// **'Audio call'**
  String get actionAudioCall;

  /// No description provided for @actionVideoCall.
  ///
  /// In en, this message translates to:
  /// **'Video call'**
  String get actionVideoCall;
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
