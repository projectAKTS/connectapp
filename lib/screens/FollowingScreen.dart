import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_screen.dart';

class FollowingScreen extends StatelessWidget {
  final List<dynamic> following;

  const FollowingScreen({Key? key, required this.following}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (following.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Following')),
        body: const Center(
          child: Text('Not following anyone yet.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Following')),
      body: ListView.builder(
        itemCount: following.length,
        itemBuilder: (context, index) {
          final userId = following[index];

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const ListTile(
                  leading: CircleAvatar(child: Icon(Icons.person)),
                  title: Text('Loading...'),
                );
              }

              final userData = snapshot.data!.data() as Map<String, dynamic>;
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: userData['profilePicture'] != null
                      ? NetworkImage(userData['profilePicture'])
                      : const AssetImage('assets/default_profile.png') as ImageProvider,
                ),
                title: Text(userData['name'] ?? 'No name'),
                subtitle: Text(userData['bio'] ?? 'No bio'),
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
      ),
    );
  }
}
