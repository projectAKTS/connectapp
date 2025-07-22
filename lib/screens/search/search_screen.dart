// lib/screens/search/search_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  final _suggestedCategories = [
    '🎓 Study Permit',
    '🏠 Housing',
    '💬 Talk to a Refugee',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String rawQuery) async {
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
      // ─── POSTS ──────────────────────────────────────
      final contentSnap = await FirebaseFirestore.instance
          .collection('posts')
          .where('content', isGreaterThanOrEqualTo: query)
          .where('content', isLessThanOrEqualTo: query + '\uf8ff')
          .get();
      final tagSnap = await FirebaseFirestore.instance
          .collection('posts')
          .where('tags', arrayContains: query)
          .get();

      final posts = <Map<String, dynamic>>[];
      for (var d in contentSnap.docs) {
        final m = Map<String, dynamic>.from(d.data() as Map<String, dynamic>);
        m['id'] = d.id;
        posts.add(m);
      }
      for (var d in tagSnap.docs) {
        final m = Map<String, dynamic>.from(d.data() as Map<String, dynamic>);
        m['id'] = d.id;
        if (!posts.any((p) => p['id'] == m['id'])) posts.add(m);
      }

      // ─── USERS ──────────────────────────────────────
      final users = <Map<String, dynamic>>[];
      Future<QuerySnapshot> byField(String field) {
        return FirebaseFirestore.instance
            .collection('users')
            .where(field, isGreaterThanOrEqualTo: query)
            .where(field, isLessThanOrEqualTo: query + '\uf8ff')
            .get();
      }
      final nameSnap = await byField('fullName');
      final bioSnap = await byField('bio');
      final journeySnap = await byField('journey');
      final tagUserSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('interestTags', arrayContains: query)
          .get();

      void addUsers(QuerySnapshot snap) {
        for (var d in snap.docs) {
          final m = Map<String, dynamic>.from(d.data() as Map<String, dynamic>);
          m['id'] = d.id;
          if (!users.any((u) => u['id'] == m['id'])) users.add(m);
        }
      }

      addUsers(nameSnap);
      addUsers(bioSnap);
      addUsers(journeySnap);
      addUsers(tagUserSnap);

      setState(() {
        postResults = posts;
        userResults = users;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        postResults.clear();
        userResults.clear();
        isLoading = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Search failed: $e')));
    }
  }

  Widget _buildPlaceholder(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFeedItems() {
    final items = <Widget>[];

    if (userResults.isNotEmpty) {
      items.add(const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text('Users',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ));
      for (var u in userResults) {
        items.add(Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage:
                  u['photoUrl'] != null ? NetworkImage(u['photoUrl']) : null,
            ),
            title: Text(u['fullName'] ?? 'Unknown'),
            subtitle: Text(u['bio'] ?? ''),
            onTap: () => Navigator.pushNamed(context, '/profile/${u['id']}'),
          ),
        ));
      }
      items.add(const Divider(height: 32));
    }

    if (postResults.isNotEmpty) {
      items.add(const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text('Posts',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ));
      for (var p in postResults) {
        final tags = (p['tags'] as List<dynamic>?)?.cast<String>() ?? [];
        items.add(Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          child: ListTile(
            leading: CircleAvatar(
              child:
                  Text((p['userName'] as String?)?.substring(0, 1) ?? 'U'),
            ),
            title: Text(p['userName'] ?? 'Anonymous'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['content'] ?? ''),
                if (tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 6,
                      children: tags
                          .map((t) => Chip(
                                label: Text(t),
                                backgroundColor: Colors.blue.shade50,
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
            onTap: () => Navigator.pushNamed(context, '/post/${p['id']}'),
          ),
        ));
      }
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search users or posts…',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _search(_searchController.text),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onSubmitted: (val) => _search(val),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : query.isEmpty
                    ? _buildPlaceholder(
                        'Suggested categories',
                        _suggestedCategories.join('   '),
                      )
                    : (userResults.isEmpty && postResults.isEmpty)
                        ? _buildPlaceholder(
                            "No results for '$query'",
                            "Try another keyword or check suggestions.",
                          )
                        : ListView(children: _buildFeedItems()),
          ),
        ],
      ),
    );
  }
}
