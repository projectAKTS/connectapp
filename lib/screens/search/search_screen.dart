// lib/screens/search/search_screen.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:connect_app/theme/tokens.dart';
import 'package:connect_app/utils/time_utils.dart';
import 'package:connect_app/screens/profile/profile_screen.dart';
import 'package:connect_app/screens/posts/post_detail_screen.dart';

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
      // USERS
      final people = <_UserHit>[];

      bool anyIndexedHit = false;
      // userName_lc prefix
      try {
        final qs = await FirebaseFirestore.instance
            .collection('users')
            .orderBy('userName_lc')
            .startAt([query])
            .endAt(['$query\uf8ff'])
            .limit(40)
            .get();
        for (final d in qs.docs) {
          people.add(_userFromDoc(d.id, d.data()));
        }
        anyIndexedHit = people.isNotEmpty;
      } catch (_) {}

      // displayName_lc prefix
      try {
        final qs = await FirebaseFirestore.instance
            .collection('users')
            .orderBy('displayName_lc')
            .startAt([query])
            .endAt(['$query\uf8ff'])
            .limit(40)
            .get();
        for (final d in qs.docs) {
          final hit = _userFromDoc(d.id, d.data());
          if (!people.any((p) => p.userId == hit.userId)) people.add(hit);
        }
        anyIndexedHit = anyIndexedHit || people.isNotEmpty;
      } catch (_) {}

      // Fallback scan (still fast enough for small datasets)
      if (!anyIndexedHit) {
        final usersSnap =
            await FirebaseFirestore.instance.collection('users').limit(300).get();
        for (final d in usersSnap.docs) {
          final m = d.data();
          final name = (m['displayName'] ?? m['userName'] ?? '').toString();
          final handle = (m['userName'] ?? '').toString();
          final bio = (m['bio'] ?? '').toString();
          final hay = '${_norm(name)} ${_norm(handle)} ${_norm(bio)}';
          if (hay.contains(query)) {
            people.add(_userFromDoc(d.id, m));
          }
        }
      }

      // POSTS
      final posts = <_PostHit>[];
      final postsSnap = await FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(120)
          .get();

      for (final d in postsSnap.docs) {
        final m = d.data();
        final content = (m['content'] ?? '').toString();
        final userName = (m['userName'] ?? 'User').toString();
        final userAvatar = (m['userAvatar'] ?? '').toString();
        final tags = (m['tags'] is List)
            ? (m['tags'] as List).map((e) => e.toString()).toList()
            : <String>[];

        final hay = '${_norm(content)} ${_norm(userName)} ${_norm(tags.join(" "))}';
        if (hay.contains(query)) {
          posts.add(_PostHit(
            id: d.id,
            authorName: userName,
            authorAvatar: userAvatar,
            content: content,
            tags: tags,
            ts: m['timestamp'],
          ));
        }
      }

      if (!mounted) return;
      setState(() {
        _userHits = people;
        _postHits = posts;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _userHits = [];
        _postHits = [];
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  _UserHit _userFromDoc(String id, Map<String, dynamic> m) {
    final name = (m['displayName'] ?? m['userName'] ?? 'User').toString();
    final handle = (m['userName'] ?? '').toString();
    final bio = (m['bio'] ?? '').toString();
    final avatar = (m['photoURL'] ?? m['avatar'] ?? '').toString();
    return _UserHit(
      userId: id,
      name: name.isEmpty ? 'User' : name,
      handle: handle,
      bio: bio,
      avatarUrl: avatar,
    );
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
        title: const Text('Search'),
      ),
      body: Column(
        children: [
          // Search pill
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: _SearchPill(
              controller: _controller,
              focusNode: _focus,
              hint: 'Search users or posts…',
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
                    uid: null, // plug in FirebaseAuth.instance.currentUser?.uid if you like
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
        final u = await fs.collection('users').doc(uid).get();
        final data = u.data() ?? {};
        recentSearches =
            ((data['searchHistory'] ?? []) as List).map((e) => e.toString()).toList();
        for (final s in recentSearches) {
          final k = _norm(s);
          if (k.isEmpty) continue;
          score[k] = (score[k] ?? 0) + 3;
        }
      } catch (_) {}
    }

    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      final snap = await fs
          .collection('posts')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoff))
          .orderBy('timestamp', descending: true)
          .limit(150)
          .get();

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
        final liked = await fs
            .collection('posts')
            .where('likedBy', arrayContains: uid)
            .orderBy('timestamp', descending: true)
            .limit(60)
            .get();
        for (final d in liked.docs) {
          final tags =
              ((d.data()['tags'] ?? []) as List).map((e) => e.toString()).toList();
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
      picked.addAll(
          ['Study Permit', 'Housing', 'Talk to a Refugee', 'Jobs', 'Healthcare', 'Documents']);
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
          'Suggested categories',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(letterSpacing: -0.2),
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
            children: _suggestions
                .map((s) => ActionChip(
                      label: Text(s, style: const TextStyle(fontWeight: FontWeight.w600)),
                      backgroundColor: AppColors.button,
                      onPressed: () => widget.onTap(s),
                      shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
                    ))
                .toList(),
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
        children.add(_SectionHeader('People'));
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
        children.add(_SectionHeader(tab == _Tab.all ? 'Posts' : ''));
        for (final p in posts) {
          children.add(_PostTile(hit: p));
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
          'No results. Try another keyword.',
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
        style:
            Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ——— Tiles ————————————————————————————————————————————————————————
class _UserTile extends StatelessWidget {
  final _UserHit hit;
  const _UserTile({required this.hit});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        leading: _Avatar(url: hit.avatarUrl, radius: 22),
        title: Text(hit.name,
            style:
                const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
        subtitle: hit.handle.isEmpty
            ? null
            : Text('@${hit.handle}', style: const TextStyle(color: AppColors.muted)),
        onTap: () {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(builder: (_) => ProfileScreen(userID: hit.userId)),
          );
        },
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  final _PostHit hit;
  const _PostTile({required this.hit});

  String _ago(dynamic ts) {
    final dt = parseFirestoreTimestamp(ts);
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo';
    return '${(diff.inDays / 365).floor()}y';
  }

  // ---- Pull "**Something Post**" from first non-empty line
  (String?, String) _extractBadgeAndBody(String raw) {
    final lines = raw.split('\n');
    int idx = 0;
    while (idx < lines.length && lines[idx].trim().isEmpty) idx++;
    if (idx >= lines.length) return (null, raw);

    final first = lines[idx].trim();
    final reg = RegExp(r'^\*\*(.+?)\*\*$'); // **Something**
    final m = reg.firstMatch(first);
    if (m != null && m.group(1) != null) {
      final label = m.group(1)!.trim();
      if (label.toLowerCase().endsWith(' post')) {
        final rest = [...lines]..removeAt(idx);
        if (idx < rest.length && rest[idx].trim().isEmpty) {
          rest.removeAt(idx);
        }
        return (label, rest.join('\n').trimLeft());
      }
    }
    return (null, raw);
  }

  // Simple markdown (**bold** only)
  TextSpan _mdSpan(String text) {
    const base = TextStyle(
      fontSize: 15.5,
      height: 1.35,
      color: AppColors.text,
    );
    const strong = TextStyle(
      fontSize: 15.5,
      height: 1.35,
      color: AppColors.text,
      fontWeight: FontWeight.w700,
    );

    final spans = <TextSpan>[];
    int i = 0;
    while (i < text.length) {
      final start = text.indexOf('**', i);
      if (start == -1) {
        spans.add(TextSpan(text: text.substring(i), style: base));
        break;
      }
      if (start > i) {
        spans.add(TextSpan(text: text.substring(i, start), style: base));
      }
      final end = text.indexOf('**', start + 2);
      if (end == -1) {
        spans.add(TextSpan(text: text.substring(start), style: base));
        break;
      }
      spans.add(TextSpan(text: text.substring(start + 2, end), style: strong));
      i = end + 2;
    }
    return TextSpan(children: spans, style: base);
  }

  Widget _postTypeBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (maybeBadge, body) = _extractBadgeAndBody(hit.content);
    final badgeLabel = maybeBadge ?? 'Quick Post';
    final contentSpan = _mdSpan(body);

    void openDetail() {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => PostDetailScreen(postId: hit.id)),
      );
    }

    return Card(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: openDetail,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header (avatar + name + time)
              Row(
                children: [
                  _Avatar(url: hit.authorAvatar, radius: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hit.authorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _ago(hit.ts),
                    style: const TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Badge + content (matching Profile/Home style)
              _postTypeBadge(badgeLabel),
              const SizedBox(height: 8),
              RichText(
                text: contentSpan,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 6),

              // NEW: explicit CTA so users know there is more
              TextButton(
                onPressed: openDetail,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.primary,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'View full post',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 13),
                  ],
                ),
              ),

              // Tags
              if (hit.tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: hit.tags
                      .map(
                        (t) => Chip(
                          label: Text(
                            t,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                          backgroundColor: AppColors.button,
                          shape: const StadiumBorder(
                            side: BorderSide(color: AppColors.border),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
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
        chip('All', _Tab.all),
        chip('People', _Tab.people),
        chip('Posts', _Tab.posts),
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
  _UserHit({
    required this.userId,
    required this.name,
    required this.handle,
    required this.bio,
    required this.avatarUrl,
  });
}

class _PostHit {
  final String id;
  final String authorName;
  final String authorAvatar;
  final String content;
  final List<String> tags;
  final dynamic ts;
  _PostHit({
    required this.id,
    required this.authorName,
    required this.authorAvatar,
    required this.content,
    required this.tags,
    required this.ts,
  });
}

// ——— Small avatar ————————————————————————————————————————————————
class _Avatar extends StatelessWidget {
  final String url;
  final double radius;
  const _Avatar({required this.url, this.radius = 20});
  @override
  Widget build(BuildContext context) => url.isEmpty
      ? CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.avatarBg,
          child:
              const Icon(Icons.person_outline, color: AppColors.avatarFg))
      : CircleAvatar(radius: radius, backgroundImage: NetworkImage(url));
}

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
    final snap = await doc.get();
    final data = (snap.data() ?? {});
    final List<dynamic> current = (data['searchHistory'] ?? []) as List<dynamic>;
    final List<String> list = current.map((e) => e.toString()).toList();

    list.removeWhere((e) => _norm(e) == t);
    list.insert(0, t);
    while (list.length > 10) list.removeLast();

    await doc.set({'searchHistory': list}, SetOptions(merge: true));
  } catch (_) {
    // ignore
  }
}
