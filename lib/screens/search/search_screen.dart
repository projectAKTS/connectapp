import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect_app/theme/tokens.dart';

// Direct screen imports (avoid named-route issues through nested navigators)
import 'package:connect_app/screens/profile/profile_screen.dart';
import 'package:connect_app/screens/posts/post_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool isLoading = false;

  List<Map<String, dynamic>> userResults = [];
  List<Map<String, dynamic>> postResults = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String rawQuery) async {
    FocusScope.of(context).unfocus();

    final query = rawQuery.trim();
    setState(() {
      userResults.clear();
      postResults.clear();
      isLoading = true;
    });
    if (query.isEmpty) {
      setState(() => isLoading = false);
      return;
    }

    try {
      // POSTS
      final contentSnap = await FirebaseFirestore.instance
          .collection('posts')
          .where('content', isGreaterThanOrEqualTo: query)
          .where('content', isLessThanOrEqualTo: '$query\uf8ff')
          .get();

      final tagSnap = await FirebaseFirestore.instance
          .collection('posts')
          .where('tags', arrayContains: query)
          .get();

      final posts = <Map<String, dynamic>>[];
      for (final d in contentSnap.docs) {
        final m = Map<String, dynamic>.from(d.data() as Map<String, dynamic>);
        m['id'] = d.id;
        posts.add(m);
      }
      for (final d in tagSnap.docs) {
        final m = Map<String, dynamic>.from(d.data() as Map<String, dynamic>);
        m['id'] = d.id;
        if (!posts.any((p) => p['id'] == m['id'])) posts.add(m);
      }

      // USERS
      final users = <Map<String, dynamic>>[];

      Future<QuerySnapshot> byField(String field) {
        return FirebaseFirestore.instance
            .collection('users')
            .where(field, isGreaterThanOrEqualTo: query)
            .where(field, isLessThanOrEqualTo: '$query\uf8ff')
            .get();
      }

      void addUsers(QuerySnapshot snap) {
        for (final d in snap.docs) {
          final m = Map<String, dynamic>.from(d.data() as Map<String, dynamic>);
          m['id'] = d.id;
          if (!users.any((u) => u['id'] == m['id'])) users.add(m);
        }
      }

      final nameSnap = await byField('fullName');
      final bioSnap = await byField('bio');
      final journeySnap = await byField('journey');
      final tagUserSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('interestTags', arrayContains: query)
          .get();

      addUsers(nameSnap);
      addUsers(bioSnap);
      addUsers(journeySnap);
      addUsers(tagUserSnap);

      if (!mounted) return;
      setState(() {
        postResults = posts;
        userResults = users;
        isLoading = false;
      });

      FocusScope.of(context).unfocus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        postResults.clear();
        userResults.clear();
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: $e')),
      );
    }
  }

  // UI helpers

  Widget _pillSearchField() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onSubmitted: _search,
      decoration: InputDecoration(
        hintText: 'Search users or posts…',
        filled: true,
        fillColor: AppColors.button,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        suffixIcon: IconButton(
          icon: const Icon(Icons.search, color: AppColors.muted),
          onPressed: () => _search(_searchController.text),
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(28),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _softCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border.withOpacity(0.65), width: 1),
        boxShadow: const [AppShadows.soft],
      ),
      child: child,
    );
  }

  Widget _userTile(Map<String, dynamic> u) {
    return _softCard(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: _avatar(url: u['photoUrl'] as String?),
        title: Text(
          (u['fullName'] ?? 'Unknown') as String,
          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
        ),
        subtitle: (u['bio'] != null && (u['bio'] as String).isNotEmpty)
            ? Text(
                u['bio'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted),
              )
            : null,
        onTap: () {
          final id = (u['id'] as String?) ?? '';
          if (id.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Missing user id')),
            );
            return;
          }
          // ✅ push on the ROOT navigator
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(builder: (_) => ProfileScreen(userID: id)),
          );
        },
      ),
    );
  }

  Widget _postTile(Map<String, dynamic> p) {
    final userName = (p['userName'] ?? 'Anonymous') as String;
    final tags = (p['tags'] as List<dynamic>?)?.cast<String>() ?? const [];

    return _softCard(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: AppColors.avatarBg,
          child: Text(
            userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
            style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(
          userName,
          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((p['content'] as String?)?.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  p['content'],
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.text),
                ),
              ),
            if (tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: -4,
                  children: tags
                      .map((t) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              t,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
        onTap: () {
          final id = (p['id'] as String?) ?? '';
          if (id.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Missing post id')),
            );
            return;
          }
          // Direct push is fine here; use root to be consistent
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(builder: (_) => PostDetailScreen(postId: id)),
          );
        },
      ),
    );
  }

  Widget _avatar({String? url}) {
    if (url == null || url.isEmpty) {
      return const CircleAvatar(
        backgroundColor: AppColors.avatarBg,
        child: Icon(Icons.person_outline, color: AppColors.avatarFg),
      );
    }
    return CircleAvatar(backgroundImage: NetworkImage(url));
  }

  Widget _placeholder() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text(
            'Suggested categories',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Try searching for things like “Study Permit”, “Housing”, or “Talk to a Refugee”.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          backgroundColor: AppColors.canvas,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: const Text('Search', style: TextStyle(color: AppColors.text)),
          centerTitle: true,
        ),
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _pillSearchField(),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : (query.isEmpty)
                      ? _placeholder()
                      : (userResults.isEmpty && postResults.isEmpty)
                          ? const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                              child: Text(
                                'No results. Try another keyword.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.muted),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              children: <Widget>[
                                if (userResults.isNotEmpty) _sectionTitle('Users'),
                                ...userResults
                                    .map((u) => Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: _userTile(u),
                                        ))
                                    .toList(),
                                if (userResults.isNotEmpty && postResults.isNotEmpty)
                                  const SizedBox(height: 8),
                                if (postResults.isNotEmpty) _sectionTitle('Posts'),
                                ...postResults
                                    .map((p) => Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: _postTile(p),
                                        ))
                                    .toList(),
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
