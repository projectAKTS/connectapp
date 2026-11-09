// lib/screens/search/search_screen.dart
import 'package:connect_app/l10n/value_labels.dart';
import 'package:connect_app/l10n/l10n.dart';
import 'dart:async';

import 'package:connect_app/models/help_topics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:connect_app/theme/tokens.dart';
import 'package:connect_app/screens/profile/profile_screen.dart';
import 'package:connect_app/screens/posts/post_detail_screen.dart';
import 'package:connect_app/services/firestore_read_helper.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:connect_app/services/safety_service.dart';
import 'package:connect_app/services/search_match.dart';
import 'package:connect_app/widgets/post_card.dart';
import 'package:connect_app/widgets/full_screen_back_gesture.dart';
import 'package:connect_app/widgets/initials_avatar.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

enum _Tab { all, people, posts }

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  Timer? _debounce;
  bool _loading = false;

  // Only the newest search may write results; older ones finish late.
  int _searchSeq = 0;

  /// The scanned users and posts, reused while typing (not refetched for
  /// every key); refreshed after a minute.
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _userScan;
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _postScan;
  DateTime _scannedAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _refreshScans() async {
    if (_userScan != null &&
        _postScan != null &&
        DateTime.now().difference(_scannedAt) < const Duration(minutes: 1)) {
      return;
    }
    final results = await Future.wait([
      FirestoreReadHelper.getQuery(
        FirebaseFirestore.instance.collection('users').limit(300),
        timeout: const Duration(seconds: 5),
      ),
      FirestoreReadHelper.getQuery(
        FirebaseFirestore.instance
            .collection('posts')
            .orderBy('timestamp', descending: true)
            .limit(200),
        timeout: const Duration(seconds: 5),
      ),
    ]);
    _userScan = results[0].docs;
    _postScan = results[1].docs;
    _scannedAt = DateTime.now();
  }
  _Tab _tab = _Tab.all;

  // Results
  List<_UserHit> _userHits = [];
  List<_PostHit> _postHits = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ——— Query handling ————————————————————————————————————————————————
  void _onChanged() {
    // Rebuild immediately so the UI switches from suggestions -> results
    setState(() {});

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () async {
      final q = _controller.text.trim();
      await _runSearch(q);
    });
  }

  Future<void> _runSearch(String raw) async {
    final seq = ++_searchSeq;
    final query = _norm(raw);
    if (query.isEmpty) {
      setState(() {
        _userHits = [];
        _postHits = [];
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    _recordSearchTerm(raw).ignore(); // best-effort, non-blocking

    try {
      // A word naming a topic in any language also matches its other names
      // ("logement" finds "Housing").
      Set<String> expand(String word) =>
          ValueLabels.topicSearchTerms(word, _norm);
      List<String> strings(dynamic v) =>
          v is List ? v.map((e) => '$e').toList() : const <String>[];

      // USERS: name prefixes (beyond the scanned page), then a scan matching
      // every word in the name, bio, expertise, interests or city.
      final userDocs = <String, Map<String, dynamic>>{};
      final rawLower = raw.trim().toLowerCase();
      await _refreshScans();
      // Name prefixes reach people beyond the scanned page only.
      final scanIsComplete = (_userScan?.length ?? 0) < 300;
      for (final field in [
        if (!scanIsComplete) 'displayName_lc',
        if (!scanIsComplete) 'userName_lc',
      ]) {
        for (final prefix in {query, rawLower}) {
          if (prefix.isEmpty) continue;
          try {
            final qs = await FirestoreReadHelper.getQuery(
              FirebaseFirestore.instance
                  .collection('users')
                  .orderBy(field)
                  .startAt([prefix]).endAt(['$prefix\uf8ff']).limit(40),
              timeout: const Duration(seconds: 5),
            );
            for (final d in qs.docs) {
              userDocs[d.id] = d.data();
            }
          } catch (_) {}
        }
      }
      for (final d in _userScan ?? const []) {
        userDocs.putIfAbsent(d.id, () => d.data());
      }
      final scoredPeople = <(int, _UserHit)>[];
      userDocs.forEach((id, m) {
        final hit = _userFromDoc(id, m);
        if (hit == null) return;
        final score = searchScore(
          query: raw,
          name: hit.name,
          fields: [
            hit.handle,
            hit.bio,
            ...strings(m['expertiseTags']),
            ...strings(m['interestTags']),
            '${m['city'] ?? ''}',
          ],
          normalize: _norm,
          expand: expand,
        );
        if (score > 0) scoredPeople.add((score, hit));
      });
      // Helpers first within the same rank: the app is for finding help.
      scoredPeople.sort((x, y) {
        final byScore = y.$1.compareTo(x.$1);
        if (byScore != 0) return byScore;
        return (y.$2.isHelper ? 1 : 0).compareTo(x.$2.isHelper ? 1 : 0);
      });
      final people = [for (final e in scoredPeople) e.$2];

      // POSTS: the latest posts, every word in the text, author or tags.
      final posts = <_PostHit>[];
      for (final d in _postScan ?? const []) {
        final m = d.data();
        final content = (m['content'] ?? '').toString();
        final userName = (m['userName'] ?? 'User').toString();
        final userAvatar = (m['userAvatar'] ?? '').toString();
        final userId = _extractPostUserId(m);
        if (SafetyService.instance.isBlocked(userId)) continue;
        if (SafetyService.instance.hidesPost(d.id, m)) continue;
        final tags = strings(m['tags']);
        final score = searchScore(
          query: raw,
          name: userName,
          fields: [content, ...tags],
          normalize: _norm,
          expand: expand,
        );
        if (score > 0) {
          posts.add(_PostHit(
            id: d.id,
            data: m,
            authorId: userId,
            authorName: userName,
            authorAvatar: userAvatar,
            content: content,
            tags: tags,
            ts: m['timestamp'],
          ));
        }
      }

      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _userHits = people;
        _postHits = posts;
      });
    } catch (_) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _userHits = [];
        _postHits = [];
      });
    } finally {
      if (mounted && seq == _searchSeq) setState(() => _loading = false);
    }
  }

  /// A person result, or null for yourself, blocked people and accounts
  /// being deleted.
  _UserHit? _userFromDoc(String id, Map<String, dynamic> m) {
    if (id == (HelperlyTestRuntime.currentUid ?? '')) return null;
    if (m['deletionRequestedAt'] != null) return null;
    if (m['ageDeclaration'] == 'minor') return null; // restricted account
    if (SafetyService.instance.isBlocked(id)) return null;
    String first(List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return '';
    }

    final name = first(['displayName', 'fullName', 'userName']);
    final role = '${m['role'] ?? ''}';
    return _UserHit(
      userId: id,
      name: name.isEmpty ? context.l10n.commonUser : name,
      handle: first(['userName']),
      bio: first(['bio']),
      // The app stores the photo as profilePicture; the others are older.
      avatarUrl: first(['profilePicture', 'photoURL', 'avatar']),
      isHelper: role == 'helper' || role == 'both' || m['isHelper'] == true,
    );
  }

  String _extractPostUserId(Map<String, dynamic> m) {
    for (final k in ['userID', 'userId', 'uid', 'authorId']) {
      final v = m[k];
      if (v is String && v.isNotEmpty) return v;
    }
    final ref = m['userRef'];
    if (ref is DocumentReference) {
      return ref.id;
    }
    try {
      final path = (ref?.path as String?);
      if (path != null && path.isNotEmpty) {
        return path.split('/').last;
      }
    } catch (_) {}
    return '';
  }

  // ——— UI ——————————————————————————————————————————————————————————————
  @override
  Widget build(BuildContext context) {
    // ✅ Use the live text field value to decide view (no race with debounce)
    final hasQuery = _controller.text.trim().isNotEmpty;

    final showPeople = _tab == _Tab.people || _tab == _Tab.all;
    final showPosts = _tab == _Tab.posts || _tab == _Tab.all;

    final people = showPeople ? _userHits : const <_UserHit>[];
    final posts = showPosts ? _postHits : const <_PostHit>[];

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        automaticallyImplyLeading: false, // 🔹 no back button in Search tab
        title: Text(context.l10n.searchTitle),
      ),
      body: Column(
        children: [
          // Search pill
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: _SearchPill(
              controller: _controller,
              focusNode: _focus,
              hint: context.l10n.searchHint,
              showClear: _controller.text.isNotEmpty,
              onClear: () {
                _controller.clear();
                // immediate UI switch back to suggestions
                setState(() {
                  _userHits = [];
                  _postHits = [];
                });
              },
            ),
          ),

          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _Tabs(
              current: _tab,
              onChanged: (t) => setState(() => _tab = t),
            ),
          ),

          const SizedBox(height: 6),

          Expanded(
            child: hasQuery
                ? _loading
                    ? const _LoadingState()
                    : _ResultsList(people: people, posts: posts, tab: _tab)
                : SuggestedCategories(
                    uid:
                        null, // plug in FirebaseAuth.instance.currentUser?.uid if you like
                    onTap: (term) {
                      _controller.text = term;
                      setState(() {}); // flip to results instantly
                      _runSearch(term);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Personalized suggestions (recent searches + trending/liked tags)
class SuggestedCategories extends StatefulWidget {
  final String? uid;
  final void Function(String term) onTap;
  const SuggestedCategories({Key? key, required this.uid, required this.onTap})
      : super(key: key);

  @override
  State<SuggestedCategories> createState() => _SuggestedCategoriesState();
}

class _SuggestedCategoriesState extends State<SuggestedCategories> {
  bool _loading = true;
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final fs = FirebaseFirestore.instance;
    final uid = widget.uid;

    final Map<String, int> score = {}; // tag -> score
    List<String> recentSearches = [];

    if (uid != null) {
      try {
        final u = await FirestoreReadHelper.getDoc(
          fs.collection('users').doc(uid),
          timeout: const Duration(seconds: 5),
        );
        final data = u.data() ?? {};
        recentSearches = ((data['searchHistory'] ?? []) as List)
            .map((e) => e.toString())
            .toList();
        for (final s in recentSearches) {
          final k = _norm(s);
          if (k.isEmpty) continue;
          score[k] = (score[k] ?? 0) + 3;
        }
      } catch (_) {}
    }

    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      final snap = await FirestoreReadHelper.getQuery(
        fs
            .collection('posts')
            .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoff))
            .orderBy('timestamp', descending: true)
            .limit(150),
        timeout: const Duration(seconds: 5),
      );

      for (final d in snap.docs) {
        final m = d.data();
        final tags =
            ((m['tags'] ?? []) as List).map((e) => e.toString()).toList();
        for (final t in tags) {
          final k = _norm(t);
          if (k.isEmpty) continue;
          score[k] = (score[k] ?? 0) + 1;
        }
        final cat = (m['category'] ?? '').toString();
        if (cat.isNotEmpty) {
          final k = _norm(cat);
          score[k] = (score[k] ?? 0) + 2;
        }
      }
    } catch (_) {}

    if (uid != null) {
      try {
        final liked = await FirestoreReadHelper.getQuery(
          fs
              .collection('posts')
              .where('likedBy', arrayContains: uid)
              .orderBy('timestamp', descending: true)
              .limit(60),
          timeout: const Duration(seconds: 5),
        );
        for (final d in liked.docs) {
          final tags = ((d.data()['tags'] ?? []) as List)
              .map((e) => e.toString())
              .toList();
          for (final t in tags) {
            final k = _norm(t);
            score[k] = (score[k] ?? 0) + 2;
          }
        }
      } catch (_) {}
    }

    final List<MapEntry<String, int>> entries = score.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    String pretty(String k) {
      for (final s in recentSearches) {
        if (_norm(s) == k) return s;
      }
      return k.isEmpty ? k : (k[0].toUpperCase() + k.substring(1));
    }

    final picked = <String>[];
    for (final e in entries) {
      if (picked.length >= 6) break;
      if (e.key.length < 2) continue;
      picked.add(pretty(e.key));
    }

    if (picked.isEmpty) {
      picked.addAll(HelpTopics.topics.take(6));
    }

    if (!mounted) return;
    setState(() {
      _suggestions = picked;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
        const SizedBox(height: 8),
        Text(
          context.l10n.searchSuggested,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(letterSpacing: -0.2),
        ),
        const SizedBox(height: 10),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions.map((s) {
              // Topic suggestions are stored ids; show and search the
              // label in the app language.
              final label = ValueLabels.topic(context.l10n, s);
              return ActionChip(
                label: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                backgroundColor: AppColors.button,
                onPressed: () => widget.onTap(label),
                shape: const StadiumBorder(
                    side: BorderSide(color: AppColors.border)),
              );
            }).toList(),
          ),
      ],
    );
  }
}

// ——— Loading/empty/results UI ————————————————————————————————————————————
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ResultsList extends StatelessWidget {
  final List<_UserHit> people;
  final List<_PostHit> posts;
  final _Tab tab;

  const _ResultsList({
    required this.people,
    required this.posts,
    required this.tab,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = [];

    if (tab == _Tab.all || tab == _Tab.people) {
      if (people.isNotEmpty) {
        children.add(_SectionHeader(context.l10n.searchPeople));
        for (final u in people) {
          children.add(_UserTile(hit: u));
        }
        children.add(const SizedBox(height: 12));
      } else if (tab == _Tab.people) {
        children.add(const _EmptyState());
      }
    }

    if (tab == _Tab.all || tab == _Tab.posts) {
      if (posts.isNotEmpty) {
        children.add(
            _SectionHeader(tab == _Tab.all ? context.l10n.searchPosts : ''));
        for (final p in posts) {
          children.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: PostCard(
              key: ValueKey(p.id),
              postId: p.id,
              data: p.data,
              onOpenDetail: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PostDetailScreen(postId: p.id),
                ),
              ),
            ),
          ));
        }
      } else if (tab == _Tab.posts) {
        children.add(const _EmptyState());
      }
    }

    if (children.isEmpty) {
      return const _EmptyState();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
      children: children,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Center(
        child: Text(
          context.l10n.searchNoResults,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox(height: 6);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ——— Tiles ————————————————————————————————————————————————————————
class _UserTile extends StatelessWidget {
  final _UserHit hit;
  const _UserTile({required this.hit});

  static Widget? _subtitle(BuildContext context, _UserHit hit) {
    final parts = [
      if (hit.isHelper) context.l10n.searchHelperBadge,
      if (hit.handle.isNotEmpty) '@${hit.handle}',
    ];
    if (parts.isEmpty) return null;
    return Text(parts.join(' · '),
        style: const TextStyle(color: AppColors.muted));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        leading: InitialsAvatar(url: hit.avatarUrl, name: hit.name, radius: 22),
        title: Text(hit.name,
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: AppColors.text)),
        subtitle: _subtitle(context, hit),
        onTap: () {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (_) => FullScreenBackGesture(
                child: ProfileScreen(userID: hit.userId),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ——— Top input + tabs ————————————————————————————————————————————————
class _SearchPill extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool showClear;
  final VoidCallback onClear;

  const _SearchPill({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.showClear,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.button,
      borderRadius: BorderRadius.circular(28),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search, color: AppColors.muted),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: hint,
                // The pill draws the background; a themed fill clipped it.
                filled: false,
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) {},
            ),
          ),
          if (showClear)
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.muted),
              onPressed: onClear,
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  final _Tab current;
  final ValueChanged<_Tab> onChanged;
  const _Tabs({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, _Tab t) {
      final sel = current == t;
      return ChoiceChip(
        label: Text(label),
        selected: sel,
        onSelected: (_) => onChanged(t),
        selectedColor: AppColors.button,
        backgroundColor: AppColors.card,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      children: [
        chip(context.l10n.searchAll, _Tab.all),
        chip(context.l10n.searchPeople, _Tab.people),
        chip(context.l10n.searchPosts, _Tab.posts),
      ],
    );
  }
}

// ——— Models ————————————————————————————————————————————————————————
class _UserHit {
  final String userId;
  final String name;
  final String handle;
  final String bio;
  final String avatarUrl;
  final bool isHelper;
  _UserHit({
    required this.userId,
    required this.name,
    required this.handle,
    required this.bio,
    required this.avatarUrl,
    this.isHelper = false,
  });
}

class _PostHit {
  final String id;
  final Map<String, dynamic> data;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final String content;
  final List<String> tags;
  final dynamic ts;
  _PostHit({
    required this.id,
    required this.data,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.content,
    required this.tags,
    required this.ts,
  });
}

// ——— Small avatar ————————————————————————————————————————————————
// ——— Normalization helper ————————————————————————————————————————————
String _norm(String s) {
  final lower = s.toLowerCase();

  const Map<String, String> repl = {
    // Turkish
    'ı': 'i', 'ğ': 'g', 'ş': 's', 'ç': 'c', 'ö': 'o', 'ü': 'u',
    // Common Latin
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', 'å': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u',
    'ñ': 'n',
  };

  final buf = StringBuffer();
  for (final cp in lower.runes) {
    final ch = String.fromCharCode(cp);
    buf.write(repl[ch] ?? ch);
  }
  return buf.toString().trim();
}

// ——— Recent-search recording (best-effort) ————————————————
extension _FutureIgnore on Future<void> {
  void ignore() {}
}

Future<void> _recordSearchTerm(String term) async {
  final t = _norm(term.trim());
  if (t.isEmpty) return;
  try {
    // If you have FirebaseAuth, plug in the uid here:
    // final uid = FirebaseAuth.instance.currentUser?.uid;
    final String? uid = null;
    if (uid == null) return;

    final doc = FirebaseFirestore.instance.collection('users').doc(uid);
    final snap = await FirestoreReadHelper.getDoc(
      doc,
      timeout: const Duration(seconds: 5),
    );
    final data = (snap.data() ?? {});
    final List<dynamic> current =
        (data['searchHistory'] ?? []) as List<dynamic>;
    final List<String> list = current.map((e) => e.toString()).toList();

    list.removeWhere((e) => _norm(e) == t);
    list.insert(0, t);
    while (list.length > 10) list.removeLast();

    await doc.set({'searchHistory': list}, SetOptions(merge: true));
  } catch (_) {
    // ignore
  }
}
