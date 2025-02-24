import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect_app/screens/posts/post_screen.dart';
import 'package:connect_app/screens/profile/profile_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({Key? key}) : super(key: key);

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedTag = "";
  late TabController _tabController;

  final List<String> _tags = ["Career", "Travel", "Health", "Technology", "Education"];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // ✅ Added Leaderboard Tab
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _search(String query) {
    setState(() {
      _searchQuery = query.trim().toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          onChanged: _search,
          decoration: InputDecoration(
            hintText: 'Search users or posts...',
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                _search("");
              },
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // 🔹 Filter Chips (Tags)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              children: _tags.map((tag) {
                final isSelected = _selectedTag == tag;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ChoiceChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedTag = selected ? tag : "";
                      });
                    },
                    selectedColor: Colors.blue,
                    backgroundColor: Colors.grey[200],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 10),

          // 🔹 Tabs (Added Leaderboard Tab)
          TabBar(
            controller: _tabController,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: const [
              Tab(text: 'For You'),
              Tab(text: 'Users'),
              Tab(text: 'Posts'),
              Tab(text: 'Leaderboard'), // ✅ New Tab for Top Helpers
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildForYouContent(),
                _buildUserSearchResults(), // ✅ Fixed Null Safety
                _buildPostSearchResults(),
                _buildLeaderboard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🧑‍💻 Users Search (Boosted Users First + Null-Safe)
  Widget _buildUserSearchResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final users = snapshot.data!.docs.where((doc) {
          final userData = doc.data() as Map<String, dynamic>;
          final name = userData['fullName']?.toString().toLowerCase() ?? '';
          final bio = userData['bio']?.toString().toLowerCase() ?? '';
          final tags = (userData['interestTags'] ?? []) as List<dynamic>;

          final matchesQuery = _searchQuery.isEmpty ||
              name.contains(_searchQuery) ||
              bio.contains(_searchQuery) ||
              tags.contains(_searchQuery);

          return matchesQuery;
        }).toList();

        // ✅ Null-Safe Highlight Check
        users.sort((a, b) {
          final aHighlight = ((a.data() as Map<String, dynamic>)['activePerks'] ?? {})['profileHighlight'] != null;
          final bHighlight = ((b.data() as Map<String, dynamic>)['activePerks'] ?? {})['profileHighlight'] != null;
          return (bHighlight ? 1 : 0) - (aHighlight ? 1 : 0);
        });

        if (users.isEmpty) {
          return const Center(child: Text('No users found'));
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final userData = user.data() as Map<String, dynamic>;
            final userId = user.id;

            final bool hasProfileHighlight = (userData['activePerks'] ?? {}).containsKey('profileHighlight');

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: AssetImage('assets/default_profile.png'),
              ),
              title: Text(userData['fullName'] ?? 'Unknown User'),
              subtitle: Text(userData['bio'] ?? ''),
              trailing: hasProfileHighlight ? const Icon(Icons.star, color: Colors.orange) : null,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(userID: userId),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // 🔥 For You Content
  Widget _buildForYouContent() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('posts').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final posts = snapshot.data!.docs.toList();

        // ✅ Prioritize posts with active boosts
        posts.sort((a, b) {
          final aBoosted = (a.data() as Map<String, dynamic>)['priorityBoost'] ?? false;
          final bBoosted = (b.data() as Map<String, dynamic>)['priorityBoost'] ?? false;
          return (bBoosted ? 1 : 0) - (aBoosted ? 1 : 0);
        });

        if (posts.isEmpty) {
          return const Center(child: Text('No content available'));
        }

        return ListView(
          children: posts.map((post) {
            final postData = post.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: AssetImage('assets/default_profile.png'),
                ),
                title: Text(postData['userName'] ?? 'Anonymous'),
                subtitle: Text(postData['content'] ?? 'No content'),
                trailing: postData['priorityBoost'] == true ? const Icon(Icons.star, color: Colors.orange) : null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PostScreen(postData: postData),
                    ),
                  );
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // 📝 Post Search
  Widget _buildPostSearchResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('posts').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final posts = snapshot.data!.docs.where((doc) {
          final postData = doc.data() as Map<String, dynamic>;
          final content = postData['content']?.toString().toLowerCase() ?? '';
          final tags = (postData['tags'] ?? []) as List<dynamic>;

          final matchesQuery = content.contains(_searchQuery);
          final matchesTag = _selectedTag.isEmpty || tags.contains(_selectedTag);

          return matchesQuery && matchesTag;
        }).toList();

        // ✅ Boosted posts first
        posts.sort((a, b) {
          final aBoosted = (a.data() as Map<String, dynamic>)['priorityBoost'] ?? false;
          final bBoosted = (b.data() as Map<String, dynamic>)['priorityBoost'] ?? false;
          return (bBoosted ? 1 : 0) - (aBoosted ? 1 : 0);
        });

        if (posts.isEmpty) {
          return const Center(child: Text('No posts found'));
        }

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final postData = post.data() as Map<String, dynamic>;

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: AssetImage('assets/default_profile.png'),
              ),
              title: Text(postData['userName'] ?? 'Anonymous'),
              subtitle: Text(postData['content'] ?? 'No content'),
              trailing: postData['priorityBoost'] == true ? const Icon(Icons.star, color: Colors.orange) : null,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PostScreen(postData: postData),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // 🏆 Leaderboard (Top 10 Helpers Based on XP)
  Widget _buildLeaderboard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('xpPoints', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final users = snapshot.data!.docs;

        if (users.isEmpty) {
          return const Center(child: Text('No top helpers found'));
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final userData = user.data() as Map<String, dynamic>;
            final userId = user.id;

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: AssetImage('assets/default_profile.png'),
              ),
              title: Text(userData['fullName'] ?? 'Unknown User'),
              subtitle: Text('${userData['xpPoints']} XP'),
              trailing: _getBadgeIcon(userData['xpPoints']),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(userID: userId),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // 🏅 Badge Icon Based on XP
  Widget? _getBadgeIcon(int xpPoints) {
    if (xpPoints >= 1000) return const Icon(Icons.emoji_events, color: Colors.purple); // 👑 Legendary Helper
    if (xpPoints >= 500) return const Icon(Icons.emoji_events, color: Colors.orange); // 🥇 Expert Helper
    if (xpPoints >= 300) return const Icon(Icons.emoji_events, color: Colors.blue); // 🥈 Skilled Helper
    if (xpPoints >= 100) return const Icon(Icons.emoji_events, color: Colors.green); // 🥉 Beginner Helper
    return null;
  }
}
