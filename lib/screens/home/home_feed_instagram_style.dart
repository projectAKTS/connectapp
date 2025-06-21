import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/post_service.dart';


class HomeFeedInstagramStyle extends StatelessWidget {
  const HomeFeedInstagramStyle({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final String? currentUserId = currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect App'),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ✅ Fixed: Story Bar without overflow
          Container(
            height: 100,
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 8,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      child: Icon(Icons.person),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'User',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),

          // 📸 Feed
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .orderBy('isBoosted', descending: true)
                  .orderBy('boostScore', descending: true)
                  .orderBy('helpfulVotes', descending: true)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No posts yet.'));
                }

                final posts = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final data = posts[index].data() as Map<String, dynamic>;
                    final String userName = data['userName'] ?? 'User';
                    final String content = data['content'] ?? 'No content';
                    final String imageUrl = data['imageUrl'] ??
                        'https://via.placeholder.com/400x400.png?text=Post+Image';
                    final Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
                    final String postId = posts[index].id;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(
                            userName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: const Icon(Icons.more_vert),
                        ),
                        AspectRatio(
                          aspectRatio: 1,
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.favorite_border),
                                onPressed: () {
                                  // TODO: implement like
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.thumb_up_alt_outlined),
                                onPressed: () {
                                  // TODO: implement helpful
                                },
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.rocket_launch),
                                onPressed: () {
                                  // TODO: implement boost
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.flag_outlined),
                                onPressed: () {
                                  // TODO: implement report
                                },
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(content),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: Text(
                            DateFormat('MMM d, yyyy').format(timestamp.toDate()),
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
