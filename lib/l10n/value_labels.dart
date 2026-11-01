import 'package:connect_app/l10n/l10n.dart';

/// Display labels for values stored in Firestore.
///
/// Topics, expertise, countries and report reasons are stored as their
/// English names, and matching compares those stored values. They are
/// identifiers: never store a translated label, and never change the stored
/// strings. Unknown values (older custom tags) are shown as stored.
///
/// Spoken languages are stored as ISO 639-1 codes (`spokenLanguages`);
/// the legacy `language` field held English names.
class ValueLabels {
  ValueLabels._();

  static String topic(AppLocalizations l, String id) {
    switch (id) {
      case 'Moving to Canada':
        return l.topicMovingToCanada;
      case 'Housing':
        return l.topicHousing;
      case 'Job hunting':
        return l.topicJobHunting;
      case 'Student life':
        return l.topicStudentLife;
      case 'Daily life in Canada':
        return l.topicDailyLife;
      case 'Language learning':
        return l.topicLanguageLearning;
      case 'Parenting support':
        return l.topicParenting;
      case 'Quebec-specific help':
        return l.topicQuebec;
      case 'Immigration experience':
        return l.topicImmigrationExperience;
      // Expertise values share this namespace (one tag list per profile).
      case 'Resume review':
        return l.expertiseResume;
      case 'Interview prep':
        return l.expertiseInterview;
      case 'Career transitions':
        return l.expertiseCareer;
      case 'Housing search':
        return l.expertiseHousingSearch;
      case 'School applications':
        return l.expertiseSchool;
      case 'Language practice':
        return l.expertiseLanguagePractice;
      case 'Settlement tips':
        return l.expertiseSettlement;
    }
    return id;
  }

  static String country(AppLocalizations l, String id) {
    switch (id) {
      case 'Canada':
        return l.countryCanada;
      case 'USA':
        return l.countryUsa;
      case 'Other':
        return l.countryOther;
    }
    return id;
  }

  /// Spoken-language codes offered in profiles, most common first for the
  /// first market. Order is display order only.
  static const List<String> languageCodes = [
    'en', 'fr', 'ar', 'es', 'zh', 'pt', 'hi', 'pa', 'ur', 'fa', 'tr', //
    'ru', 'uk', 'tl', 'vi', 'ko', 'it', 'de', 'ro', 'bn', 'ht',
  ];

  /// A language code ('tr') or a legacy English name ('English').
  static String language(AppLocalizations l, String value) {
    switch (codeForLanguage(value)) {
      case 'en':
        return l.langEn;
      case 'fr':
        return l.langFr;
      case 'ar':
        return l.langAr;
      case 'es':
        return l.langEs;
      case 'pt':
        return l.langPt;
      case 'zh':
        return l.langZh;
      case 'hi':
        return l.langHi;
      case 'pa':
        return l.langPa;
      case 'ur':
        return l.langUr;
      case 'fa':
        return l.langFa;
      case 'tr':
        return l.langTr;
      case 'ru':
        return l.langRu;
      case 'uk':
        return l.langUk;
      case 'tl':
        return l.langTl;
      case 'vi':
        return l.langVi;
      case 'ko':
        return l.langKo;
      case 'it':
        return l.langIt;
      case 'de':
        return l.langDe;
      case 'ro':
        return l.langRo;
      case 'bn':
        return l.langBn;
      case 'ht':
        return l.langHt;
    }
    return value == 'Other' ? l.langOther : value;
  }

  /// The ISO code for a stored language value: codes pass through, legacy
  /// English names ('English', 'French') map to codes, 'Other' and unknown
  /// names give null.
  static String? codeForLanguage(String value) {
    final v = value.trim();
    if (languageCodes.contains(v)) return v;
    switch (v.toLowerCase()) {
      case 'english':
        return 'en';
      case 'french':
      case 'français':
      case 'francais':
        return 'fr';
    }
    return null;
  }

  static String reportReason(AppLocalizations l, String id) {
    switch (id) {
      case 'Spam or scam':
        return l.reportSpam;
      case 'Harassment or hate':
        return l.reportHarassment;
      case 'Inappropriate content':
        return l.reportInappropriate;
      case 'Harmful or misleading advice':
        return l.reportHarmfulAdvice;
      case 'Pretending to be someone else':
        return l.reportImpersonation;
      case 'Something else':
        return l.reportOther;
    }
    return id;
  }

  /// The badge for a stored post type ('Quick', 'Experience', ...). English
  /// badges are unchanged ("Experience Post"); unknown types keep the old
  /// rule of appending " Post".
  static String postType(AppLocalizations l, String raw) {
    final t = raw.trim();
    switch (t.toLowerCase()) {
      case '':
      case 'quick':
      case 'quick post':
        return l.postTypeQuick;
      case 'experience':
      case 'experience post':
        return l.postTypeExperience;
      case 'advice request':
      case 'advice request post':
        return l.postTypeAdvice;
      case 'how-to guide':
      case 'how-to guide post':
        return l.postTypeHowTo;
      case 'lessons learned':
      case 'lessons learned post':
        return l.postTypeLessons;
    }
    return t.endsWith('Post') ? t : '$t Post';
  }

  /// A stored badge such as "🏅 First Contributor": the emoji is kept and
  /// the name translated. Unknown badges are shown as stored.
  static String badge(AppLocalizations l, String stored) {
    final m = RegExp(r'^(\S+)\s+(.+)$').firstMatch(stored.trim());
    if (m == null) return stored;
    final emoji = m[1]!;
    final name = m[2]!;
    final label = switch (name) {
      'Kind Contributor' => l.badgeKindContributor,
      'Premium Trial' => l.badgePremiumTrial,
      'Profile Highlight' => l.badgeProfileHighlight,
      'Trusted Problem Solver' => l.badgeTrustedProblemSolver,
      'First Contributor' => l.badgeFirstContributor,
      'Legendary Helper' => l.badgeLegendaryHelper,
      'Dedicated Contributor' => l.badgeDedicatedContributor,
      'Conversationalist' => l.badgeConversationalist,
      'Streak Starter' => l.badgeStreakStarter,
      'Boost Enthusiast' => l.badgeBoostEnthusiast,
      'Priority Post Boost' => l.badgePriorityPostBoost,
      'Expert Helper' => l.badgeExpertHelper,
      'Skilled Helper' => l.badgeSkilledHelper,
      'Beginner Helper' => l.badgeBeginnerHelper,
      'Community Mentor' => l.badgeCommunityMentor,
      _ => null,
    };
    return label == null ? stored : '$emoji $label';
  }

  /// Search needles for [normalizedQuery]: the query itself, plus every
  /// language's label and the stored id of each topic or expertise whose
  /// label (in any language) contains it. So "logement" also finds posts
  /// tagged "Housing". [normalize] must be the caller's text normalizer.
  static Set<String> topicSearchTerms(
      String normalizedQuery, String Function(String) normalize) {
    final terms = <String>{normalizedQuery};
    if (normalizedQuery.length < 3) return terms;
    final locales =
        AppLocalizations.supportedLocales.map(lookupAppLocalizations).toList();
    for (final id in topicIds) {
      final labels = {
        id,
        for (final l in locales) topic(l, id),
      }.map(normalize).toSet();
      if (labels.any((label) => label.contains(normalizedQuery))) {
        terms.addAll(labels);
      }
    }
    return terms;
  }

  /// Every stored topic and expertise id with a label.
  static const List<String> topicIds = [
    'Moving to Canada', 'Housing', 'Job hunting', 'Student life', //
    'Daily life in Canada', 'Language learning', 'Parenting support',
    'Quebec-specific help', 'Immigration experience', 'Resume review',
    'Interview prep', 'Career transitions', 'Housing search',
    'School applications', 'Language practice', 'Settlement tips',
  ];
}
