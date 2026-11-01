import 'package:connect_app/l10n/value_labels.dart';

/// The languages a person speaks, as ISO 639-1 codes in
/// `users/{uid}.spokenLanguages`. This is not the app's interface language
/// (`appLocale`), and one never fills in the other.
///
/// Older profiles have only the single legacy `language` field ('English',
/// 'French' or 'Other'), and installed builds before this change require it
/// to be non-empty to skip onboarding. So every save writes both fields,
/// and reads fall back to the legacy one.
class ProfileLanguages {
  ProfileLanguages._();

  static const String field = 'spokenLanguages';
  static const String legacyField = 'language';

  /// Spoken-language codes for a user doc, newest field first.
  static List<String> read(Map<String, dynamic> data) {
    final raw = data[field];
    if (raw is List) {
      final codes = <String>[];
      for (final v in raw) {
        final code = ValueLabels.codeForLanguage('$v');
        if (code != null && !codes.contains(code)) codes.add(code);
      }
      if (codes.isNotEmpty) return codes;
    }
    // Older docs: the legacy single value, or a never-written list.
    final codes = <String>[];
    for (final v in [
      data[legacyField],
      if (data['languages'] is List) ...(data['languages'] as List),
    ]) {
      final code = ValueLabels.codeForLanguage('${v ?? ''}');
      if (code != null && !codes.contains(code)) codes.add(code);
    }
    return codes;
  }

  /// True when the profile states any language, old or new field. Used by
  /// the onboarding gate.
  static bool hasAny(Map<String, dynamic> data) =>
      read(data).isNotEmpty || '${data[legacyField] ?? ''}'.trim().isNotEmpty;

  /// The fields to save for [codes]. The legacy value keeps older builds
  /// out of onboarding: 'English' or 'French' when spoken, else 'Other'.
  /// Empty [codes] save nothing, so a partial save never clears a legacy
  /// value the new list could not express (such as 'Other').
  static Map<String, dynamic> fields(List<String> codes) {
    if (codes.isEmpty) return const {};
    return {
      field: codes,
      legacyField: codes.contains('en')
          ? 'English'
          : codes.contains('fr')
              ? 'French'
              : 'Other',
    };
  }
}
