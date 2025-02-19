import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect_app/screens/posts/post_screen.dart';
import 'package:connect_app/screens/profile/profile_screen.dart';

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
    _tabController = TabController(length: 2, vsync: this); // ✅ Fixed Initialization
  }

  @override
  void dispose() {
    _tabController.dispose(); // ✅ Properly Dispose Controller
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
        title: const Text('Explore'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 🔎 Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _search,
              decoration: InputDecoration(
                labelText: 'Search users or posts...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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

          // 🔹 Instagram-Like Tabs for Users & Posts
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
            child: TabBarView(
              controller: _tabController,
              children: [
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
          final journey = userData['journey']?.toString().toLowerCase() ?? '';
          final tags = (userData['interestTags'] ?? []) as List<dynamic>;

          final matchesQuery = _searchQuery.isEmpty ||
              name.contains(_searchQuery) ||
              bio.contains(_searchQuery) ||
              journey.contains(_searchQuery) ||
              tags.contains(_searchQuery);

          return matchesQuery;
        }).toList();

        if (users.isEmpty) {
          return const Center(child: Text('No users found'));
        }

        return ListView(
          children: users.map((user) {
            final userData = user.data() as Map<String, dynamic>;
            final userId = user.id; // ✅ Fix: Get userID instead of userData

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ListTile(
                title: Text(userData['fullName'] ?? 'Unknown User'),
                subtitle: Text(userData['bio'] ?? ''),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(userID: userId), // ✅ Fix: Pass userID
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

        return ListView(
          children: posts.map((post) {
            final postData = post.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ListTile(
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
}
