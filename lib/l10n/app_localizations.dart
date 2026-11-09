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
  /// **'Your profile and posts will be deleted and you will be signed out. Messages you sent stay visible to the people you sent them to. This can\'t be undone.'**
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

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found!'**
  String get profileNotFound;

  /// No description provided for @profileLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load profile.'**
  String get profileLoadFailed;

  /// No description provided for @profileLoginToFollow.
  ///
  /// In en, this message translates to:
  /// **'Please log in to follow users.'**
  String get profileLoginToFollow;

  /// No description provided for @profileFollowFailed.
  ///
  /// In en, this message translates to:
  /// **'Follow action failed. Please try again.'**
  String get profileFollowFailed;

  /// No description provided for @profileUnblocked.
  ///
  /// In en, this message translates to:
  /// **'{name} is unblocked.'**
  String profileUnblocked(String name);

  /// No description provided for @profileSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileSettings;

  /// No description provided for @profileMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get profileMore;

  /// No description provided for @profileReportUser.
  ///
  /// In en, this message translates to:
  /// **'Report user'**
  String get profileReportUser;

  /// No description provided for @profileUnblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get profileUnblock;

  /// No description provided for @profileFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get profileFollowing;

  /// No description provided for @profileFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get profileFollow;

  /// No description provided for @profileReviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get profileReviews;

  /// No description provided for @profileSocial.
  ///
  /// In en, this message translates to:
  /// **'Social'**
  String get profileSocial;

  /// No description provided for @profileFollowers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get profileFollowers;

  /// No description provided for @profileFollowingList.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get profileFollowingList;

  /// No description provided for @profilePeopleCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person} other{{count} people}}'**
  String profilePeopleCount(int count);

  /// No description provided for @profileMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get profileMessages;

  /// No description provided for @profileConversationsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 conversation} other{{count} conversations}}'**
  String profileConversationsCount(int count);

  /// No description provided for @profileOpenConversations.
  ///
  /// In en, this message translates to:
  /// **'Open conversations'**
  String get profileOpenConversations;

  /// No description provided for @profileMyConsultations.
  ///
  /// In en, this message translates to:
  /// **'My consultations'**
  String get profileMyConsultations;

  /// No description provided for @profileConsultationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upcoming & past sessions'**
  String get profileConsultationsSubtitle;

  /// No description provided for @profileBilling.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get profileBilling;

  /// No description provided for @profileCardOnFile.
  ///
  /// In en, this message translates to:
  /// **'Card on file'**
  String get profileCardOnFile;

  /// No description provided for @profileAddCard.
  ///
  /// In en, this message translates to:
  /// **'Add a card for consultations'**
  String get profileAddCard;

  /// No description provided for @profilePremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get profilePremium;

  /// No description provided for @profilePremiumNotActive.
  ///
  /// In en, this message translates to:
  /// **'Not active'**
  String get profilePremiumNotActive;

  /// No description provided for @profilePremiumExpires.
  ///
  /// In en, this message translates to:
  /// **'{status} • Expires {date}'**
  String profilePremiumExpires(String status, String date);

  /// No description provided for @profileBadges.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get profileBadges;

  /// No description provided for @profileMoreBadges.
  ///
  /// In en, this message translates to:
  /// **'+ {count} more'**
  String profileMoreBadges(int count);

  /// No description provided for @profileFeaturedPosts.
  ///
  /// In en, this message translates to:
  /// **'Featured Posts'**
  String get profileFeaturedPosts;

  /// No description provided for @profileNoFeaturedPosts.
  ///
  /// In en, this message translates to:
  /// **'No featured posts yet.'**
  String get profileNoFeaturedPosts;

  /// No description provided for @profileRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get profileRecentActivity;

  /// No description provided for @profileNoActivity.
  ///
  /// In en, this message translates to:
  /// **'No activity yet.'**
  String get profileNoActivity;

  /// No description provided for @profileLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load this right now.'**
  String get profileLoadError;

  /// No description provided for @profileStatHelpful.
  ///
  /// In en, this message translates to:
  /// **'Helpful'**
  String get profileStatHelpful;

  /// No description provided for @profileStatRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get profileStatRating;

  /// No description provided for @profileStatStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get profileStatStreak;

  /// No description provided for @profileStatXp.
  ///
  /// In en, this message translates to:
  /// **'XP'**
  String get profileStatXp;

  /// No description provided for @profileStreakDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String profileStreakDays(int count);

  /// No description provided for @profileNoWrittenReviews.
  ///
  /// In en, this message translates to:
  /// **'No written reviews yet.'**
  String get profileNoWrittenReviews;

  /// No description provided for @profileBookedSession.
  ///
  /// In en, this message translates to:
  /// **'Booked session'**
  String get profileBookedSession;

  /// No description provided for @profileBookedSessionOn.
  ///
  /// In en, this message translates to:
  /// **'Booked session · {date}'**
  String profileBookedSessionOn(String date);

  /// No description provided for @profileBioMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get profileBioMore;

  /// No description provided for @postFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get postFilterAll;

  /// No description provided for @postFilterQuick.
  ///
  /// In en, this message translates to:
  /// **'Quick'**
  String get postFilterQuick;

  /// No description provided for @postFilterExperience.
  ///
  /// In en, this message translates to:
  /// **'Experience'**
  String get postFilterExperience;

  /// No description provided for @postFilterAdvice.
  ///
  /// In en, this message translates to:
  /// **'Advice Request'**
  String get postFilterAdvice;

  /// No description provided for @postFilterHowTo.
  ///
  /// In en, this message translates to:
  /// **'How-To Guide'**
  String get postFilterHowTo;

  /// No description provided for @postFilterLessons.
  ///
  /// In en, this message translates to:
  /// **'Lessons Learned'**
  String get postFilterLessons;

  /// No description provided for @editProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfileTitle;

  /// No description provided for @editProfileSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save your profile. Please try again.'**
  String get editProfileSaveFailed;

  /// No description provided for @editProfileNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Display name is required.'**
  String get editProfileNameRequired;

  /// No description provided for @editProfileBio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get editProfileBio;

  /// No description provided for @editProfileBioHint.
  ///
  /// In en, this message translates to:
  /// **'Write a short intro about yourself'**
  String get editProfileBioHint;

  /// No description provided for @editProfileLocationLanguage.
  ///
  /// In en, this message translates to:
  /// **'Location & Language'**
  String get editProfileLocationLanguage;

  /// No description provided for @editProfileCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get editProfileCountry;

  /// No description provided for @editProfilePreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get editProfilePreferences;

  /// No description provided for @editProfileRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get editProfileRole;

  /// No description provided for @editProfileRoleGetHelp.
  ///
  /// In en, this message translates to:
  /// **'Get Help'**
  String get editProfileRoleGetHelp;

  /// No description provided for @editProfileRoleGiveHelp.
  ///
  /// In en, this message translates to:
  /// **'Give Help'**
  String get editProfileRoleGiveHelp;

  /// No description provided for @editProfileRoleBoth.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get editProfileRoleBoth;

  /// No description provided for @editProfileTopics.
  ///
  /// In en, this message translates to:
  /// **'Topics'**
  String get editProfileTopics;

  /// No description provided for @editProfileTopicsHelper.
  ///
  /// In en, this message translates to:
  /// **'Comma separated (e.g. Housing, Student life)'**
  String get editProfileTopicsHelper;

  /// No description provided for @editProfileSkills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get editProfileSkills;

  /// No description provided for @editProfileCommaSeparated.
  ///
  /// In en, this message translates to:
  /// **'Comma separated'**
  String get editProfileCommaSeparated;

  /// No description provided for @editProfileExperience.
  ///
  /// In en, this message translates to:
  /// **'Experience'**
  String get editProfileExperience;

  /// No description provided for @editProfileHelperProfile.
  ///
  /// In en, this message translates to:
  /// **'Helper Profile'**
  String get editProfileHelperProfile;

  /// No description provided for @editProfileModeChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get editProfileModeChat;

  /// No description provided for @editProfileModeCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get editProfileModeCall;

  /// No description provided for @editProfileModeVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get editProfileModeVideo;

  /// No description provided for @editProfileSet.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get editProfileSet;

  /// No description provided for @editProfileSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get editProfileSaveChanges;

  /// No description provided for @commonUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get commonUser;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @messagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messagesTitle;

  /// No description provided for @messagesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet.'**
  String get messagesEmpty;

  /// No description provided for @messagesLoginAgain.
  ///
  /// In en, this message translates to:
  /// **'Please log in again.'**
  String get messagesLoginAgain;

  /// No description provided for @messagesOpenToView.
  ///
  /// In en, this message translates to:
  /// **'(Open to view messages)'**
  String get messagesOpenToView;

  /// No description provided for @messagePhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get messagePhoto;

  /// No description provided for @messageVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get messageVideo;

  /// No description provided for @messageFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get messageFile;

  /// No description provided for @messageMissedCall.
  ///
  /// In en, this message translates to:
  /// **'Missed call'**
  String get messageMissedCall;

  /// No description provided for @chatTitleFallback.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatTitleFallback;

  /// No description provided for @chatThisPerson.
  ///
  /// In en, this message translates to:
  /// **'this person'**
  String get chatThisPerson;

  /// No description provided for @chatYouBlocked.
  ///
  /// In en, this message translates to:
  /// **'You blocked this person. Unblock them to send messages.'**
  String get chatYouBlocked;

  /// No description provided for @chatSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Message could not be sent. Please try again.'**
  String get chatSendFailed;

  /// No description provided for @chatAttachFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t attach the file. Please try again.'**
  String get chatAttachFailed;

  /// No description provided for @chatAttachmentSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t send the attachment. Please try again.'**
  String get chatAttachmentSendFailed;

  /// No description provided for @chatReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get chatReport;

  /// No description provided for @chatInitFailed.
  ///
  /// In en, this message translates to:
  /// **'Chat could not open. Please reopen this chat.'**
  String get chatInitFailed;

  /// No description provided for @chatInputHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get chatInputHint;

  /// No description provided for @chatEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages here yet'**
  String get chatEmpty;

  /// No description provided for @chatAttachLabel.
  ///
  /// In en, this message translates to:
  /// **'Send media'**
  String get chatAttachLabel;

  /// No description provided for @chatFileLabel.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get chatFileLabel;

  /// No description provided for @chatSendLabel.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSendLabel;

  /// No description provided for @chatTyping.
  ///
  /// In en, this message translates to:
  /// **'is typing'**
  String get chatTyping;

  /// No description provided for @chatOthers.
  ///
  /// In en, this message translates to:
  /// **'others'**
  String get chatOthers;

  /// No description provided for @chatAnd.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get chatAnd;

  /// No description provided for @chatUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread messages'**
  String get chatUnread;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search users or posts…'**
  String get searchHint;

  /// No description provided for @searchSuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested categories'**
  String get searchSuggested;

  /// No description provided for @searchPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get searchPeople;

  /// No description provided for @searchPosts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get searchPosts;

  /// No description provided for @searchAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get searchAll;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results. Try another keyword.'**
  String get searchNoResults;

  /// No description provided for @searchHelperBadge.
  ///
  /// In en, this message translates to:
  /// **'Helper'**
  String get searchHelperBadge;

  /// No description provided for @searchViewFullPost.
  ///
  /// In en, this message translates to:
  /// **'View full post'**
  String get searchViewFullPost;

  /// No description provided for @createTemplates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get createTemplates;

  /// No description provided for @createSetQuick.
  ///
  /// In en, this message translates to:
  /// **'Set Quick'**
  String get createSetQuick;

  /// No description provided for @createTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a post'**
  String get createTitle;

  /// No description provided for @createPosting.
  ///
  /// In en, this message translates to:
  /// **'Posting...'**
  String get createPosting;

  /// No description provided for @createRemoveAll.
  ///
  /// In en, this message translates to:
  /// **'Remove all'**
  String get createRemoveAll;

  /// No description provided for @createAddFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Add from library'**
  String get createAddFromLibrary;

  /// No description provided for @createUseCamera.
  ///
  /// In en, this message translates to:
  /// **'Use camera'**
  String get createUseCamera;

  /// No description provided for @createNoMedia.
  ///
  /// In en, this message translates to:
  /// **'No media added yet.'**
  String get createNoMedia;

  /// No description provided for @createTagHint.
  ///
  /// In en, this message translates to:
  /// **'Add a tag (e.g. career)'**
  String get createTagHint;

  /// No description provided for @createQuickHint.
  ///
  /// In en, this message translates to:
  /// **'What do you want to talk about?'**
  String get createQuickHint;

  /// No description provided for @createQuickPost.
  ///
  /// In en, this message translates to:
  /// **'Quick post'**
  String get createQuickPost;

  /// No description provided for @createTemplate.
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get createTemplate;

  /// No description provided for @createMedia.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get createMedia;

  /// No description provided for @createMediaCount.
  ///
  /// In en, this message translates to:
  /// **'Media ({count})'**
  String createMediaCount(int count);

  /// No description provided for @createTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get createTags;

  /// No description provided for @createTagsCount.
  ///
  /// In en, this message translates to:
  /// **'Tags ({count})'**
  String createTagsCount(int count);

  /// No description provided for @createAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get createAdd;

  /// No description provided for @createLoginToPost.
  ///
  /// In en, this message translates to:
  /// **'Please log in to post'**
  String get createLoginToPost;

  /// No description provided for @createPosted.
  ///
  /// In en, this message translates to:
  /// **'Posted ✅'**
  String get createPosted;

  /// No description provided for @createPostFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not post. Please try again.'**
  String get createPostFailed;

  /// No description provided for @tplExperienceQ1.
  ///
  /// In en, this message translates to:
  /// **'What happened?'**
  String get tplExperienceQ1;

  /// No description provided for @tplExperienceQ2.
  ///
  /// In en, this message translates to:
  /// **'What did you learn?'**
  String get tplExperienceQ2;

  /// No description provided for @tplExperienceQ3.
  ///
  /// In en, this message translates to:
  /// **'What advice would you give others?'**
  String get tplExperienceQ3;

  /// No description provided for @tplAdviceQ1.
  ///
  /// In en, this message translates to:
  /// **'What’s your challenge or question?'**
  String get tplAdviceQ1;

  /// No description provided for @tplAdviceQ2.
  ///
  /// In en, this message translates to:
  /// **'What have you tried so far?'**
  String get tplAdviceQ2;

  /// No description provided for @tplAdviceQ3.
  ///
  /// In en, this message translates to:
  /// **'What kind of advice do you need?'**
  String get tplAdviceQ3;

  /// No description provided for @tplHowToQ1.
  ///
  /// In en, this message translates to:
  /// **'What are you explaining?'**
  String get tplHowToQ1;

  /// No description provided for @tplHowToQ2.
  ///
  /// In en, this message translates to:
  /// **'List the steps clearly'**
  String get tplHowToQ2;

  /// No description provided for @tplHowToQ3.
  ///
  /// In en, this message translates to:
  /// **'What’s the key takeaway?'**
  String get tplHowToQ3;

  /// No description provided for @tplLessonsQ1.
  ///
  /// In en, this message translates to:
  /// **'Topic of your lesson'**
  String get tplLessonsQ1;

  /// No description provided for @tplLessonsQ2.
  ///
  /// In en, this message translates to:
  /// **'List 3–10 lessons or takeaways'**
  String get tplLessonsQ2;

  /// No description provided for @tplLessonsQ3.
  ///
  /// In en, this message translates to:
  /// **'One key message for others'**
  String get tplLessonsQ3;

  /// No description provided for @tplQuickDesc.
  ///
  /// In en, this message translates to:
  /// **'Write freely in one field.'**
  String get tplQuickDesc;

  /// No description provided for @tplExperienceDesc.
  ///
  /// In en, this message translates to:
  /// **'Share a story + what you learned.'**
  String get tplExperienceDesc;

  /// No description provided for @tplAdviceDesc.
  ///
  /// In en, this message translates to:
  /// **'Ask a question and add context.'**
  String get tplAdviceDesc;

  /// No description provided for @tplHowToDesc.
  ///
  /// In en, this message translates to:
  /// **'Explain steps so others can follow.'**
  String get tplHowToDesc;

  /// No description provided for @tplLessonsDesc.
  ///
  /// In en, this message translates to:
  /// **'Summarize takeaways from a topic.'**
  String get tplLessonsDesc;

  /// No description provided for @postDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get postDetailTitle;

  /// No description provided for @postNotFound.
  ///
  /// In en, this message translates to:
  /// **'Post not found.'**
  String get postNotFound;

  /// No description provided for @postUnknownDate.
  ///
  /// In en, this message translates to:
  /// **'Unknown date'**
  String get postUnknownDate;

  /// No description provided for @postPostedOn.
  ///
  /// In en, this message translates to:
  /// **'Posted on {date}'**
  String postPostedOn(String date);

  /// No description provided for @commentHint.
  ///
  /// In en, this message translates to:
  /// **'Write a comment...'**
  String get commentHint;

  /// No description provided for @commentNone.
  ///
  /// In en, this message translates to:
  /// **'No comments yet.'**
  String get commentNone;

  /// No description provided for @commentJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get commentJustNow;

  /// No description provided for @commentNoContent.
  ///
  /// In en, this message translates to:
  /// **'No content'**
  String get commentNoContent;

  /// No description provided for @commentFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not post your comment. Please try again.'**
  String get commentFailed;

  /// No description provided for @postProTip.
  ///
  /// In en, this message translates to:
  /// **'💡 Pro Tip'**
  String get postProTip;

  /// No description provided for @postAddComment.
  ///
  /// In en, this message translates to:
  /// **'Add a comment...'**
  String get postAddComment;

  /// No description provided for @postLikes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 like} other{{count} likes}}'**
  String postLikes(int count);

  /// No description provided for @editPostTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Post'**
  String get editPostTitle;

  /// No description provided for @editPostContent.
  ///
  /// In en, this message translates to:
  /// **'Post Content'**
  String get editPostContent;

  /// No description provided for @editPostUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update Post'**
  String get editPostUpdate;

  /// No description provided for @editPostUpdated.
  ///
  /// In en, this message translates to:
  /// **'Post updated successfully!'**
  String get editPostUpdated;

  /// No description provided for @editPostFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update the post. Please try again.'**
  String get editPostFailed;

  /// No description provided for @consultCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel consultation?'**
  String get consultCancelTitle;

  /// No description provided for @consultCancelBody.
  ///
  /// In en, this message translates to:
  /// **'Canceling may trigger a refund based on the cancellation policy.'**
  String get consultCancelBody;

  /// No description provided for @consultKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get consultKeep;

  /// No description provided for @consultCanceledNoRefund.
  ///
  /// In en, this message translates to:
  /// **'Canceled. No refund (within 1 hour).'**
  String get consultCanceledNoRefund;

  /// No description provided for @consultNotScheduled.
  ///
  /// In en, this message translates to:
  /// **'Not scheduled'**
  String get consultNotScheduled;

  /// No description provided for @consultJoinSoon.
  ///
  /// In en, this message translates to:
  /// **'Join soon'**
  String get consultJoinSoon;

  /// No description provided for @consultExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get consultExpired;

  /// No description provided for @consultReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to join'**
  String get consultReady;

  /// No description provided for @consultLoginToView.
  ///
  /// In en, this message translates to:
  /// **'Please log in to view consultations.'**
  String get consultLoginToView;

  /// No description provided for @consultTitle.
  ///
  /// In en, this message translates to:
  /// **'My Consultations'**
  String get consultTitle;

  /// No description provided for @consultLoadError.
  ///
  /// In en, this message translates to:
  /// **'Error loading consultations.'**
  String get consultLoadError;

  /// No description provided for @consultNone.
  ///
  /// In en, this message translates to:
  /// **'No consultations found.'**
  String get consultNone;

  /// No description provided for @consultUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get consultUpcoming;

  /// No description provided for @consultNoUpcoming.
  ///
  /// In en, this message translates to:
  /// **'No upcoming consultations.'**
  String get consultNoUpcoming;

  /// No description provided for @consultNoPartner.
  ///
  /// In en, this message translates to:
  /// **'No partner found for this consultation.'**
  String get consultNoPartner;

  /// No description provided for @consultPast.
  ///
  /// In en, this message translates to:
  /// **'Past consultations'**
  String get consultPast;

  /// No description provided for @consultNoPast.
  ///
  /// In en, this message translates to:
  /// **'No past consultations yet.'**
  String get consultNoPast;

  /// No description provided for @consultCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get consultCompleted;

  /// No description provided for @consultRated.
  ///
  /// In en, this message translates to:
  /// **'You rated this session'**
  String get consultRated;

  /// No description provided for @consultRate.
  ///
  /// In en, this message translates to:
  /// **'Rate this session'**
  String get consultRate;

  /// No description provided for @consultJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get consultJoin;

  /// No description provided for @consultCanceledRefund.
  ///
  /// In en, this message translates to:
  /// **'Canceled. Refund: {amount} ({percent}%).'**
  String consultCanceledRefund(String amount, int percent);

  /// No description provided for @consultCancelFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not cancel. Please try again.'**
  String get consultCancelFailed;

  /// No description provided for @consultJoinIn.
  ///
  /// In en, this message translates to:
  /// **'Join available in {wait}'**
  String consultJoinIn(String wait);

  /// No description provided for @consultJoinOpensEarly.
  ///
  /// In en, this message translates to:
  /// **'Join opens {minutes} min early'**
  String consultJoinOpensEarly(int minutes);

  /// No description provided for @consultCanceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get consultCanceled;

  /// No description provided for @consultMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String consultMinutes(int minutes);

  /// No description provided for @consultCost.
  ///
  /// In en, this message translates to:
  /// **'Cost: {cost}'**
  String consultCost(String cost);

  /// No description provided for @bookRespondsHour.
  ///
  /// In en, this message translates to:
  /// **'Usually responds within an hour'**
  String get bookRespondsHour;

  /// No description provided for @bookResponds2h.
  ///
  /// In en, this message translates to:
  /// **'Usually responds within 2 hours'**
  String get bookResponds2h;

  /// No description provided for @bookRespondsToday.
  ///
  /// In en, this message translates to:
  /// **'Usually responds today'**
  String get bookRespondsToday;

  /// No description provided for @bookRespondsDay.
  ///
  /// In en, this message translates to:
  /// **'Usually responds within a day'**
  String get bookRespondsDay;

  /// No description provided for @bookPickDateTime.
  ///
  /// In en, this message translates to:
  /// **'Please pick a date and time.'**
  String get bookPickDateTime;

  /// No description provided for @bookSignIn.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to continue.'**
  String get bookSignIn;

  /// No description provided for @bookAddCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a card to continue'**
  String get bookAddCardTitle;

  /// No description provided for @bookAddCardBody.
  ///
  /// In en, this message translates to:
  /// **'You don’t have a saved payment method yet. Add one now to complete the booking.'**
  String get bookAddCardBody;

  /// No description provided for @bookAddCard.
  ///
  /// In en, this message translates to:
  /// **'Add Card'**
  String get bookAddCard;

  /// No description provided for @bookSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please sign in again.'**
  String get bookSessionExpired;

  /// No description provided for @bookPaymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed. Please try again.'**
  String get bookPaymentFailed;

  /// No description provided for @bookBooked.
  ///
  /// In en, this message translates to:
  /// **'Consultation booked successfully.'**
  String get bookBooked;

  /// No description provided for @bookTitle.
  ///
  /// In en, this message translates to:
  /// **'Book a Consultation'**
  String get bookTitle;

  /// No description provided for @bookSelectDuration.
  ///
  /// In en, this message translates to:
  /// **'Select duration'**
  String get bookSelectDuration;

  /// No description provided for @bookCallType.
  ///
  /// In en, this message translates to:
  /// **'Call type'**
  String get bookCallType;

  /// No description provided for @bookAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get bookAudio;

  /// No description provided for @bookVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get bookVideo;

  /// No description provided for @bookPickATime.
  ///
  /// In en, this message translates to:
  /// **'Pick a time'**
  String get bookPickATime;

  /// No description provided for @bookPickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick date'**
  String get bookPickDate;

  /// No description provided for @bookPickTime.
  ///
  /// In en, this message translates to:
  /// **'Pick time'**
  String get bookPickTime;

  /// No description provided for @bookSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get bookSummary;

  /// No description provided for @bookPremiumFree.
  ///
  /// In en, this message translates to:
  /// **'Premium: 5 min free audio applied'**
  String get bookPremiumFree;

  /// No description provided for @bookPayout.
  ///
  /// In en, this message translates to:
  /// **'{amount} to helper'**
  String bookPayout(String amount);

  /// No description provided for @bookFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not book. Please try again.'**
  String get bookFailed;

  /// No description provided for @bookScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled: {when}'**
  String bookScheduled(String when);

  /// No description provided for @bookSummaryLine.
  ///
  /// In en, this message translates to:
  /// **'Type: {type} • Duration: {minutes} min'**
  String bookSummaryLine(String type, int minutes);

  /// No description provided for @bookTotal.
  ///
  /// In en, this message translates to:
  /// **'Total: {price}'**
  String bookTotal(String price);

  /// No description provided for @bookButton.
  ///
  /// In en, this message translates to:
  /// **'Book consultation ({price})'**
  String bookButton(String price);

  /// No description provided for @reviewSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save your rating. Please try again.'**
  String get reviewSaveFailed;

  /// No description provided for @reviewThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks for rating your session.'**
  String get reviewThanks;

  /// No description provided for @reviewShownOnProfile.
  ///
  /// In en, this message translates to:
  /// **'Your rating and comment are shown on their profile.'**
  String get reviewShownOnProfile;

  /// No description provided for @reviewHint.
  ///
  /// In en, this message translates to:
  /// **'What helped? (optional)'**
  String get reviewHint;

  /// No description provided for @reviewSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit rating'**
  String get reviewSubmit;

  /// No description provided for @reviewHowWas.
  ///
  /// In en, this message translates to:
  /// **'How was your session with {name}?'**
  String reviewHowWas(String name);

  /// No description provided for @reviewStars.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 star} other{{count} stars}}'**
  String reviewStars(int count);

  /// No description provided for @contentRejected.
  ///
  /// In en, this message translates to:
  /// **'This looks like it breaks our Community guidelines. Please edit it and try again.'**
  String get contentRejected;

  /// No description provided for @callEnded.
  ///
  /// In en, this message translates to:
  /// **'Call ended'**
  String get callEnded;

  /// No description provided for @callConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Call connection failed. Please try again.'**
  String get callConnectionFailed;

  /// No description provided for @callTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Call connection timed out. Please try again.'**
  String get callTimedOut;

  /// No description provided for @callNetworkFailed.
  ///
  /// In en, this message translates to:
  /// **'Call network failed. Please try again.'**
  String get callNetworkFailed;

  /// No description provided for @callSetupFailed.
  ///
  /// In en, this message translates to:
  /// **'Call setup failed. Please try again.'**
  String get callSetupFailed;

  /// No description provided for @callMicRequired.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is required for this call.'**
  String get callMicRequired;

  /// No description provided for @callNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'No answer'**
  String get callNoAnswer;

  /// No description provided for @callDeclined.
  ///
  /// In en, this message translates to:
  /// **'User declined or unavailable'**
  String get callDeclined;

  /// No description provided for @callUnavailable.
  ///
  /// In en, this message translates to:
  /// **'User unavailable'**
  String get callUnavailable;

  /// No description provided for @callClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get callClose;

  /// No description provided for @callConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get callConnecting;

  /// No description provided for @callAudioTitle.
  ///
  /// In en, this message translates to:
  /// **'Audio call'**
  String get callAudioTitle;

  /// No description provided for @callVideoTitle.
  ///
  /// In en, this message translates to:
  /// **'Video call'**
  String get callVideoTitle;

  /// No description provided for @callSomethingWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get callSomethingWrong;

  /// No description provided for @callOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get callOpenSettings;

  /// No description provided for @callAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get callAccept;

  /// No description provided for @callDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get callDecline;

  /// No description provided for @connectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get connectionsTitle;

  /// No description provided for @connectionsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load connections.'**
  String get connectionsLoadFailed;

  /// No description provided for @connectionsConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected {when}'**
  String connectionsConnected(String when);

  /// No description provided for @followSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again.'**
  String get followSignInAgain;

  /// No description provided for @followNoFollowers.
  ///
  /// In en, this message translates to:
  /// **'No followers yet.'**
  String get followNoFollowers;

  /// No description provided for @followNoFollowing.
  ///
  /// In en, this message translates to:
  /// **'Not following anyone yet.'**
  String get followNoFollowing;

  /// No description provided for @payRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove card?'**
  String get payRemoveTitle;

  /// No description provided for @payRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'This card will be removed from your account.'**
  String get payRemoveBody;

  /// No description provided for @payRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get payRemove;

  /// No description provided for @payMakeDefault.
  ///
  /// In en, this message translates to:
  /// **'Make default'**
  String get payMakeDefault;

  /// No description provided for @payRemoveCard.
  ///
  /// In en, this message translates to:
  /// **'Remove card'**
  String get payRemoveCard;

  /// No description provided for @payCardAdded.
  ///
  /// In en, this message translates to:
  /// **'✅ Card added successfully!'**
  String get payCardAdded;

  /// No description provided for @payTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get payTitle;

  /// No description provided for @payAddCard.
  ///
  /// In en, this message translates to:
  /// **'Add a card'**
  String get payAddCard;

  /// No description provided for @paySavedCards.
  ///
  /// In en, this message translates to:
  /// **'Saved cards'**
  String get paySavedCards;

  /// No description provided for @payLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load cards'**
  String get payLoadFailed;

  /// No description provided for @payCardOptions.
  ///
  /// In en, this message translates to:
  /// **'Card options'**
  String get payCardOptions;

  /// No description provided for @paySetupFailed.
  ///
  /// In en, this message translates to:
  /// **'Card setup failed.'**
  String get paySetupFailed;

  /// No description provided for @callAlreadyInProgress.
  ///
  /// In en, this message translates to:
  /// **'A call is already in progress.'**
  String get callAlreadyInProgress;

  /// No description provided for @callFinishingPrevious.
  ///
  /// In en, this message translates to:
  /// **'Finishing previous call...'**
  String get callFinishingPrevious;

  /// No description provided for @callUnableToStart.
  ///
  /// In en, this message translates to:
  /// **'Unable to start call. Check your connection.'**
  String get callUnableToStart;

  /// No description provided for @callWaitingOther.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the other user to join…'**
  String get callWaitingOther;

  /// No description provided for @callTapToSwap.
  ///
  /// In en, this message translates to:
  /// **'Tap to swap'**
  String get callTapToSwap;

  /// No description provided for @callIncomingVideo.
  ///
  /// In en, this message translates to:
  /// **'Incoming Video Call'**
  String get callIncomingVideo;

  /// No description provided for @callIncomingAudio.
  ///
  /// In en, this message translates to:
  /// **'Incoming Audio Call'**
  String get callIncomingAudio;

  /// No description provided for @callIncomingVideoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Incoming video call'**
  String get callIncomingVideoSubtitle;

  /// No description provided for @callIncomingAudioSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Incoming audio call'**
  String get callIncomingAudioSubtitle;

  /// No description provided for @payCanceled.
  ///
  /// In en, this message translates to:
  /// **'Card setup canceled.'**
  String get payCanceled;

  /// No description provided for @payUsedFor.
  ///
  /// In en, this message translates to:
  /// **'Used for consultation bookings. You can update it anytime.'**
  String get payUsedFor;

  /// No description provided for @paySecurely.
  ///
  /// In en, this message translates to:
  /// **'Securely save a default card for faster checkout.'**
  String get paySecurely;

  /// No description provided for @payNoCards.
  ///
  /// In en, this message translates to:
  /// **'No saved cards yet.'**
  String get payNoCards;

  /// No description provided for @payRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing cards…'**
  String get payRefreshing;

  /// No description provided for @callFlip.
  ///
  /// In en, this message translates to:
  /// **'Flip'**
  String get callFlip;

  /// No description provided for @consultCallTitle.
  ///
  /// In en, this message translates to:
  /// **'Consultation Call'**
  String get consultCallTitle;

  /// No description provided for @consultCallWith.
  ///
  /// In en, this message translates to:
  /// **'Consultation • {name}'**
  String consultCallWith(String name);

  /// No description provided for @callMuted.
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get callMuted;

  /// No description provided for @callMic.
  ///
  /// In en, this message translates to:
  /// **'Mic'**
  String get callMic;

  /// No description provided for @callCameraOff.
  ///
  /// In en, this message translates to:
  /// **'Camera off'**
  String get callCameraOff;

  /// No description provided for @callCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get callCamera;

  /// No description provided for @callEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get callEnd;

  /// No description provided for @payDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get payDefault;

  /// No description provided for @payExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires {month}/{year}'**
  String payExpires(String month, String year);

  /// No description provided for @consultWaitingOther.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the other participant…'**
  String get consultWaitingOther;

  /// No description provided for @callCaller.
  ///
  /// In en, this message translates to:
  /// **'Caller'**
  String get callCaller;

  /// No description provided for @callChannelName.
  ///
  /// In en, this message translates to:
  /// **'Incoming calls'**
  String get callChannelName;

  /// No description provided for @settingsCrashReports.
  ///
  /// In en, this message translates to:
  /// **'Send crash reports'**
  String get settingsCrashReports;

  /// No description provided for @settingsCrashReportsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Technical details when the app crashes (device model, app version, error), not linked to your account. Off unless you turn it on.'**
  String get settingsCrashReportsSubtitle;

  /// No description provided for @badgeKindContributor.
  ///
  /// In en, this message translates to:
  /// **'Kind Contributor'**
  String get badgeKindContributor;

  /// No description provided for @badgePremiumTrial.
  ///
  /// In en, this message translates to:
  /// **'Premium Trial'**
  String get badgePremiumTrial;

  /// No description provided for @badgeProfileHighlight.
  ///
  /// In en, this message translates to:
  /// **'Profile Highlight'**
  String get badgeProfileHighlight;

  /// No description provided for @badgeTrustedProblemSolver.
  ///
  /// In en, this message translates to:
  /// **'Trusted Problem Solver'**
  String get badgeTrustedProblemSolver;

  /// No description provided for @badgeFirstContributor.
  ///
  /// In en, this message translates to:
  /// **'First Contributor'**
  String get badgeFirstContributor;

  /// No description provided for @badgeLegendaryHelper.
  ///
  /// In en, this message translates to:
  /// **'Legendary Helper'**
  String get badgeLegendaryHelper;

  /// No description provided for @badgeDedicatedContributor.
  ///
  /// In en, this message translates to:
  /// **'Dedicated Contributor'**
  String get badgeDedicatedContributor;

  /// No description provided for @badgeConversationalist.
  ///
  /// In en, this message translates to:
  /// **'Conversationalist'**
  String get badgeConversationalist;

  /// No description provided for @badgeStreakStarter.
  ///
  /// In en, this message translates to:
  /// **'Streak Starter'**
  String get badgeStreakStarter;

  /// No description provided for @badgeBoostEnthusiast.
  ///
  /// In en, this message translates to:
  /// **'Boost Enthusiast'**
  String get badgeBoostEnthusiast;

  /// No description provided for @badgePriorityPostBoost.
  ///
  /// In en, this message translates to:
  /// **'Priority Post Boost'**
  String get badgePriorityPostBoost;

  /// No description provided for @badgeExpertHelper.
  ///
  /// In en, this message translates to:
  /// **'Expert Helper'**
  String get badgeExpertHelper;

  /// No description provided for @badgeSkilledHelper.
  ///
  /// In en, this message translates to:
  /// **'Skilled Helper'**
  String get badgeSkilledHelper;

  /// No description provided for @badgeBeginnerHelper.
  ///
  /// In en, this message translates to:
  /// **'Beginner Helper'**
  String get badgeBeginnerHelper;

  /// No description provided for @badgeCommunityMentor.
  ///
  /// In en, this message translates to:
  /// **'Community Mentor'**
  String get badgeCommunityMentor;

  /// No description provided for @bookPaymentPending.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t confirm the payment yet. Tap Book again in a moment; you won’t be charged twice.'**
  String get bookPaymentPending;

  /// No description provided for @ageCheckbox.
  ///
  /// In en, this message translates to:
  /// **'I confirm I am 18 or older.'**
  String get ageCheckbox;

  /// No description provided for @ageRequired.
  ///
  /// In en, this message translates to:
  /// **'Helperly is for people 18 and older.'**
  String get ageRequired;

  /// No description provided for @ageConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Helperly is for adults'**
  String get ageConfirmTitle;

  /// No description provided for @ageConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Helperly connects people who don\'t know each other, including by message and call, so it is only for people 18 and older. Please confirm your age to continue.'**
  String get ageConfirmBody;

  /// No description provided for @ageImAdult.
  ///
  /// In en, this message translates to:
  /// **'I\'m 18 or older'**
  String get ageImAdult;

  /// No description provided for @ageImMinor.
  ///
  /// In en, this message translates to:
  /// **'I\'m under 18'**
  String get ageImMinor;

  /// No description provided for @ageMinorConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Are you under 18?'**
  String get ageMinorConfirmTitle;

  /// No description provided for @ageMinorConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Your account will be paused. You can then delete it, or contact us if this was a mistake.'**
  String get ageMinorConfirmBody;

  /// No description provided for @ageMinorConfirm.
  ///
  /// In en, this message translates to:
  /// **'Yes, I\'m under 18'**
  String get ageMinorConfirm;

  /// No description provided for @ageRestrictedTitle.
  ///
  /// In en, this message translates to:
  /// **'Your account is paused'**
  String get ageRestrictedTitle;

  /// No description provided for @ageRestrictedBody.
  ///
  /// In en, this message translates to:
  /// **'Helperly is only for people 18 and older, so this account can\'t be used. Your data is kept until you delete the account or we review it. If this is a mistake, contact us at {email}.'**
  String ageRestrictedBody(String email);

  /// No description provided for @consentTitle.
  ///
  /// In en, this message translates to:
  /// **'Help us improve Helperly'**
  String get consentTitle;

  /// No description provided for @consentBody.
  ///
  /// In en, this message translates to:
  /// **'Both are optional and off unless you turn them on. You can change them anytime in Settings.'**
  String get consentBody;

  /// No description provided for @chatSafetyTips.
  ///
  /// In en, this message translates to:
  /// **'Stay safe: never send money, codes or passwords, and keep your conversations in Helperly. Report anything that makes you uncomfortable.'**
  String get chatSafetyTips;

  /// No description provided for @chatFirstContactTitle.
  ///
  /// In en, this message translates to:
  /// **'First time talking with {name}'**
  String chatFirstContactTitle(String name);

  /// No description provided for @chatFirstContactBody.
  ///
  /// In en, this message translates to:
  /// **'You don\'t know this person yet. Reply only if you want to. You can block or report them.'**
  String get chatFirstContactBody;

  /// No description provided for @chatWaitingForReply.
  ///
  /// In en, this message translates to:
  /// **'Photos and links can be sent after {name} replies.'**
  String chatWaitingForReply(String name);

  /// No description provided for @callNeedsReply.
  ///
  /// In en, this message translates to:
  /// **'You can call this person after they reply to your message.'**
  String get callNeedsReply;

  /// No description provided for @chatScamWarning.
  ///
  /// In en, this message translates to:
  /// **'Be careful: {name} mentioned money, codes or another app. Never send money or codes, and keep your conversations in Helperly.'**
  String chatScamWarning(String name);

  /// No description provided for @reportCallBehaviour.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate behaviour during a call'**
  String get reportCallBehaviour;

  /// No description provided for @chatTapToView.
  ///
  /// In en, this message translates to:
  /// **'Photo hidden · Tap to view'**
  String get chatTapToView;

  /// No description provided for @postSensitiveTapToView.
  ///
  /// In en, this message translates to:
  /// **'Sensitive content · Tap to view'**
  String get postSensitiveTapToView;

  /// No description provided for @postComment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get postComment;

  /// No description provided for @postCommentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get postCommentsTitle;

  /// No description provided for @commentSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get commentSend;

  /// No description provided for @commentDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete comment'**
  String get commentDelete;

  /// No description provided for @commentReport.
  ///
  /// In en, this message translates to:
  /// **'Report comment'**
  String get commentReport;

  /// No description provided for @commentDeleted.
  ///
  /// In en, this message translates to:
  /// **'Comment deleted'**
  String get commentDeleted;

  /// No description provided for @profilePosts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get profilePosts;
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
