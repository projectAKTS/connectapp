/// Blocks clearly objectionable words before posts, comments and messages are
/// saved. App Store guideline 1.2 requires a filtering method for
/// user-generated content, alongside reporting and blocking.
///
/// Matching is whole-word, after lowercasing and undoing common character
/// swaps (0→o, 1→i, @→a, ...), so innocent words that merely contain a
/// blocked one ("assistant", "Scunthorpe") pass. The list is deliberately
/// short: severe slurs and explicit sexual terms in the app's main
/// languages. Reports and moderation handle everything subtler.
class ContentFilter {
  ContentFilter._();

  static const String rejectionMessage =
      'This looks like it breaks our Community guidelines. '
      'Please edit it and try again.';

  static const Set<String> _blocked = {
    // English: slurs
    'nigger', 'niggers', 'nigga', 'niggas', 'faggot', 'faggots', 'chink',
    'chinks', 'spic', 'spics', 'kike',
    'kikes', 'wetback', 'wetbacks', 'tranny', 'trannies', 'paki', 'pakis',
    'raghead', 'ragheads', 'towelhead', 'gook',
    'gooks', // English: explicit sexual
    'cunt', 'cunts', 'porn', 'porno', 'blowjob', 'handjob', 'cumshot',
    'gangbang', 'pussy', 'whore',
    'whores', 'slut', 'sluts', 'motherfucker', 'motherfuckers', 'fuck',
    'fucking', 'fucker', 'fucked',
    // French
    'salope', 'salopes', 'pute', 'putes', 'enculé', 'encule', 'connasse',
    'nègre', 'negre',
    // Turkish
    'orospu', 'orospuçocuğu', 'orospucocugu', 'amına', 'sikerim',
    'siktir', 'yarrak', 'piç', 'pezevenk', 'göt', 'ibne',
    // Spanish
    'puta', 'putas', 'maricón', 'maricon', 'pendejo', 'cabrón', 'cabron',
  };

  static const Map<String, String> _swaps = {
    '0': 'o',
    '1': 'i',
    '3': 'e',
    '4': 'a',
    '5': 's',
    '7': 't',
    '@': 'a',
    r'$': 's',
    '!': 'i',
  };

  /// True when [text] contains no blocked word.
  static bool isAllowed(String text) => blockedWordIn(text) == null;

  /// The first blocked word found in [text], or null.
  static String? blockedWordIn(String text) {
    final buffer = StringBuffer();
    for (final rune in text.toLowerCase().runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(_swaps[ch] ?? ch);
    }
    final words = buffer
        .toString()
        .split(RegExp(r"[^a-zà-ÿğüşöçıİ]+", unicode: true))
        .where((w) => w.isNotEmpty);
    for (final word in words) {
      if (_blocked.contains(word)) return word;
    }
    return null;
  }
}
