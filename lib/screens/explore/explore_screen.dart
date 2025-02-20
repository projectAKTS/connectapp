import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect_app/screens/posts/post_screen.dart';
import 'package:connect_app/screens/profile/profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({Key? key}) : super(key: key);

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedTag = "";
  late TabController _tabController;

  final List<String> _tags = ["Career", "Travel", "Health", "Technology", "Education"];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // ✅ Fixed Tab Initialization
  }

  @override
  void dispose() {
    _tabController.dispose(); // ✅ Dispose Properly
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

          // 🔹 Instagram-Like Tabs
          TabBar(
            controller: _tabController,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue, // ✅ Highlight selected tab
            tabs: const [
              Tab(text: 'For You'),
              Tab(text: 'Users'),
              Tab(text: 'Posts'),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(), // ✅ Fixed to make it clickable
              children: [
                // 🔥 For You Tab
                _buildForYouContent(),

                // 🧑‍💻 Users Tab
                _buildUserSearchResults(),

                // 📝 Posts Tab
                _buildPostSearchResults(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 For You Content
  Widget _buildForYouContent() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('posts').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final posts = snapshot.data!.docs.take(10).toList(); // ✅ Limit to 10 posts for now

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

  // 🔍 Search Users
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

        if (users.isEmpty) {
          return const Center(child: Text('No users found'));
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
              subtitle: Text(userData['bio'] ?? ''),
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

  // 🔍 Search Posts
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
}
