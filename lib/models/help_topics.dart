/// The one list of help topics and helper expertise, shared by onboarding,
/// edit profile, Find a helper and Search.
///
/// Helperly's MVP is settlement experience for newcomers to Canada, not
/// legal advice: paid immigration advice in Canada is limited to licensed
/// consultants (RCIC) and lawyers, so immigration topics are experience
/// sharing only. Values are stored on user docs as-is; keep existing strings
/// unchanged when editing these lists.
class HelpTopics {
  HelpTopics._();

  /// What a seeker needs help with.
  static const List<String> topics = [
    'Moving to Canada',
    'Housing',
    'Job hunting',
    'Student life',
    'Daily life in Canada',
    'Language learning',
    'Parenting support',
    'Quebec-specific help',
    immigrationExperience,
  ];

  /// What a helper can help with.
  static const List<String> expertise = [
    'Resume review',
    'Interview prep',
    'Career transitions',
    'Housing search',
    'School applications',
    'Language practice',
    'Settlement tips',
    immigrationExperience,
  ];

  /// Shared personal experience only; never legal advice.
  static const String immigrationExperience = 'Immigration experience';

  /// Shown wherever people look for or book help.
  static const String adviceNotice =
      'Helpers share personal experience. This is not legal, immigration '
      'or medical advice.';
}
