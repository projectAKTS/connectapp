import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_screen.dart';

class FollowersScreen extends StatelessWidget {
  final List<dynamic> followers;

  const FollowersScreen({Key? key, required this.followers}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (followers.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Followers')),
        body: const Center(
          child: Text('No followers yet.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Followers')),
      body: ListView.builder(
        itemCount: followers.length,
        itemBuilder: (context, index) {
          final userId = followers[index];

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
