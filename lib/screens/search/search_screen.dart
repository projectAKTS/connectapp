import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> postResults = [];
  List<Map<String, dynamic>> userResults = [];
  bool isLoading = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // 🔹 2 Tabs: Users & Posts
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() {
        postResults.clear();
        userResults.clear();
      });
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // 🔍 Search Posts by content and tags
      QuerySnapshot postSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('content', isGreaterThanOrEqualTo: query)
          .where('content', isLessThanOrEqualTo: query + '\uf8ff')
          .get();

      QuerySnapshot tagSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('tags', arrayContains: query)
          .get();

      List<Map<String, dynamic>> posts = [];
      for (var doc in postSnapshot.docs) {
        posts.add(doc.data() as Map<String, dynamic>);
      }
      for (var doc in tagSnapshot.docs) {
        Map<String, dynamic> post = doc.data() as Map<String, dynamic>;
        if (!posts.any((p) => p['id'] == post['id'])) {
          posts.add(post);
        }
      }

      // 🔍 Search Users by fullName, bio, journey, and interestTags
      List<Map<String, dynamic>> users = [];

      QuerySnapshot nameSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('fullName', isGreaterThanOrEqualTo: query)
          .where('fullName', isLessThanOrEqualTo: query + '\uf8ff')
          .get();

      QuerySnapshot bioSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('bio', isGreaterThanOrEqualTo: query)
          .where('bio', isLessThanOrEqualTo: query + '\uf8ff')
          .get();

      QuerySnapshot journeySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('journey', isGreaterThanOrEqualTo: query)
          .where('journey', isLessThanOrEqualTo: query + '\uf8ff')
          .get();

      QuerySnapshot interestTagSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('interestTags', arrayContains: query)
          .get();

      // ✅ Combine user results while avoiding duplicates
      for (var doc in nameSnapshot.docs) {
        users.add(doc.data() as Map<String, dynamic>);
      }
      for (var doc in bioSnapshot.docs) {
        Map<String, dynamic> user = doc.data() as Map<String, dynamic>;
        if (!users.any((u) => u['id'] == user['id'])) {
          users.add(user);
        }
      }
      for (var doc in journeySnapshot.docs) {
        Map<String, dynamic> user = doc.data() as Map<String, dynamic>;
        if (!users.any((u) => u['id'] == user['id'])) {
          users.add(user);
        }
      }
      for (var doc in interestTagSnapshot.docs) {
        Map<String, dynamic> user = doc.data() as Map<String, dynamic>;
        if (!users.any((u) => u['id'] == user['id'])) {
          users.add(user);
        }
      }

      setState(() {
        postResults = posts;
        userResults = users;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users or posts...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _search(_searchController.text.trim()),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onSubmitted: (value) => _search(value.trim()),
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Users'),
              Tab(text: 'Posts'),
            ],
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // 🔹 Users Tab
                      userResults.isEmpty
                          ? const Center(child: Text('No users found'))
                          : ListView(
                              children: userResults.map((user) => Card(
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 16),
                                    child: ListTile(
                                      title: Text(user['fullName'] ??
                                          'Unknown User'),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(user['bio'] ?? ''),
                                          if (user['interestTags'] != null)
                                            Wrap(
                                              spacing: 6.0,
                                              children: (user['interestTags']
                                                          as List<dynamic>?)
                                                      ?.map((tag) => Chip(
                                                            label: Text(tag),
                                                            backgroundColor:
                                                                Colors.blue
                                                                    .shade100,
                                                          ))
                                                      .toList() ??
                                                  [],
                                            ),
                                        ],
                                      ),
                                    ),
                                  )).toList(),
                            ),

                      // 🔹 Posts Tab
                      postResults.isEmpty
                          ? const Center(child: Text('No posts found'))
                          : ListView(
                              children: postResults.map((post) {
                                List<String> tags =
                                    (post['tags'] as List<dynamic>?)
                                            ?.cast<String>() ??
                                        [];

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 16),
                                  child: ListTile(
                                    title:
                                        Text(post['userName'] ?? 'Anonymous'),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(post['content'] ?? 'No content'),
                                        if (tags.isNotEmpty)
                                          Wrap(
                                            spacing: 6.0,
                                            children: tags
                                                .map((tag) => Chip(
                                                      label: Text(tag),
                                                      backgroundColor: Colors
                                                          .blue.shade100,
                                                    ))
                                                .toList(),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
