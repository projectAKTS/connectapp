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
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _search(String query) {
    setState(() {
      _searchQuery = query.trim().toLowerCase();
    });
  }

  // Helper function to compute engagement score for posts
  int computeEngagementScore(Map<String, dynamic> postData) {
    int likes = postData['likes'] ?? 0;
    int helpful = postData['helpfulVotes'] ?? 0;
    int comments = postData['commentsCount'] ?? 0;
    return (helpful * 2) + likes + comments;
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
          TabBar(
            controller: _tabController,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: const [
              Tab(text: 'For You'),
              Tab(text: 'Users'),
              Tab(text: 'Posts'),
              Tab(text: 'Leaderboard'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildForYouContent(),
                _buildUserSearchResults(),
                _buildPostSearchResults(),
                _buildLeaderboard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForYouContent() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('posts').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final posts = snapshot.data!.docs.toList();
        posts.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aBoost = aData['priorityBoost'] ?? false;
          final bBoost = bData['priorityBoost'] ?? false;
          if (aBoost != bBoost) {
            return bBoost ? 1 : -1;
          }
          int aScore = computeEngagementScore(aData);
          int bScore = computeEngagementScore(bData);
          return bScore.compareTo(aScore);
        });
        if (posts.isEmpty) return const Center(child: Text('No content available'));
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

        users.sort((a, b) {
          final aHighlight = ((a.data() as Map<String, dynamic>)['activePerks'] ?? {})['profileHighlight'] != null;
          final bHighlight = ((b.data() as Map<String, dynamic>)['activePerks'] ?? {})['profileHighlight'] != null;
          return (bHighlight ? 1 : 0) - (aHighlight ? 1 : 0);
        });

        if (users.isEmpty) return const Center(child: Text('No users found'));
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

        posts.sort((a, b) {
          final aBoosted = (a.data() as Map<String, dynamic>)['priorityBoost'] ?? false;
          final bBoosted = (b.data() as Map<String, dynamic>)['priorityBoost'] ?? false;
          if (aBoosted != bBoosted) {
            return (bBoosted ? 1 : 0) - (aBoosted ? 1 : 0);
          }
          int aScore = computeEngagementScore(a.data() as Map<String, dynamic>);
          int bScore = computeEngagementScore(b.data() as Map<String, dynamic>);
          return bScore.compareTo(aScore);
        });

        if (posts.isEmpty) return const Center(child: Text('No posts found'));
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
        if (users.isEmpty) return const Center(child: Text('No top helpers found'));
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

  Widget? _getBadgeIcon(int xpPoints) {
    if (xpPoints >= 1000) return const Icon(Icons.emoji_events, color: Colors.purple);
    if (xpPoints >= 500) return const Icon(Icons.emoji_events, color: Colors.orange);
    if (xpPoints >= 300) return const Icon(Icons.emoji_events, color: Colors.blue);
    if (xpPoints >= 100) return const Icon(Icons.emoji_events, color: Colors.green);
    return null;
  }
}
