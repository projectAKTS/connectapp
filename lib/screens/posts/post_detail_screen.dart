// lib/screens/posts/post_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:connect_app/utils/time_utils.dart';

class PostDetailScreen extends StatelessWidget {
  final String postId;
  const PostDetailScreen({Key? key, required this.postId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post Detail')),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('posts')
            .doc(postId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Post not found.'));
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;

          // 👇 Robust timestamp handling
          final dt = parseFirestoreTimestamp(data['timestamp']);
          final date = dt != null
              ? DateFormat.yMMMd().add_jm().format(dt)
              : 'Unknown date';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['userName'] ?? 'Anonymous',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (data['imageUrl'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(data['imageUrl']),
                  ),
                if (data['imageUrl'] != null) const SizedBox(height: 12),
                Text(
                  data['content'] ?? '',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Text(
                  'Posted on $date',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
