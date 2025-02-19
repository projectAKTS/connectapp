import 'package:flutter/material.dart';

class PostScreen extends StatelessWidget {
  final Map<String, dynamic> postData;

  const PostScreen({Key? key, required this.postData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<String> tags = (postData['tags'] as List<dynamic>?)?.cast<String>() ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(postData['userName'] ?? 'Post Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              postData['content'] ?? 'No content available',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            // Display Tags
            if (tags.isNotEmpty)
              Wrap(
                spacing: 8.0,
                children: tags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    backgroundColor: Colors.blue.shade100,
                  );
                }).toList(),
              ),

            const SizedBox(height: 16),

            Row(
              children: [
                const Icon(Icons.favorite, color: Colors.red),
                const SizedBox(width: 4),
                Text('${postData['likes']} likes'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
