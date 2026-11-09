/// Keyword match used by the in-app search.
///
/// Every word of the query must appear somewhere in [name] or [fields], in
/// any order. [expand] adds equivalent terms for a word (a topic named in
/// another language). Returns 0 for no match, otherwise a rank: the name
/// starting with the query, then the name containing every word, then a
/// match elsewhere (bio, expertise, post text).
///
/// shortcut: scans what the client already loaded (a few hundred users and
/// the latest posts); move to a search service when the data outgrows that.
int searchScore({
  required String query,
  required String name,
  required List<String> fields,
  required String Function(String) normalize,
  Set<String> Function(String word)? expand,
}) {
  final q = normalize(query).trim();
  if (q.isEmpty) return 0;
  final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final n = normalize(name);
  final hay = '$n ${fields.map(normalize).join(' ')}';
  bool hit(String text, String word) =>
      (expand?.call(word) ?? {word}).any(text.contains);
  if (!words.every((w) => hit(hay, w))) return 0;
  if (n.startsWith(q) || n.split(RegExp(r'\s+')).any((p) => p.startsWith(q))) {
    return 3;
  }
  if (words.every((w) => hit(n, w))) return 2;
  return 1;
}
