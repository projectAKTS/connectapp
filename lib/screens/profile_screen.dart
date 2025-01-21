import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import 'FollowersScreen.dart';
import 'FollowingScreen.dart';

class ProfileScreen extends StatefulWidget {
  final String userID;

  const ProfileScreen({Key? key, required this.userID}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? currentUserId; // Nullable to handle initialization properly
  bool isFollowing = false;

  @override
  void initState() {
    super.initState();
    _initializeCurrentUser();
  }

  /// Initializes the current user ID
  void _initializeCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      setState(() {
        currentUserId = user.uid;
      });
      _checkIfFollowing();
    } else {
      // Handle null user (e.g., navigate to login or show error)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User is not logged in.')),
      );
    }
  }

  /// Checks if the current user is following the profile user
  Future<void> _checkIfFollowing() async {
    if (currentUserId == null) return;

    final userSnapshot = await FirebaseFirestore.instance.collection('users').doc(widget.userID).get();
    final followers = userSnapshot.data()?['followers'] as List<dynamic>? ?? [];

    setState(() {
      isFollowing = followers.contains(currentUserId);
    });
  }

  /// Toggles the follow/unfollow state and updates Firestore
  Future<void> _toggleFollow() async {
    if (currentUserId == null) return;

    final firestoreService = FirestoreService();
    if (isFollowing) {
      await firestoreService.updateFollowersFollowing(
        currentUserId: currentUserId!,
        targetUserId: widget.userID,
        isFollow: false,
      );
      setState(() {
        isFollowing = false;
      });
    } else {
      await firestoreService.updateFollowersFollowing(
        currentUserId: currentUserId!,
        targetUserId: widget.userID,
        isFollow: true,
      );
      setState(() {
        isFollowing = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
      ),
      body: currentUserId == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').doc(widget.userID).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.data() == null) {
                  return const Center(child: Text('Error loading profile.'));
                }

                final userData = snapshot.data!.data()!;
                final followersCount = (userData['followers'] as List<dynamic>?)?.length ?? 0;
                final followingCount = (userData['following'] as List<dynamic>?)?.length ?? 0;

                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Profile Picture
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: userData['profilePicture'] != null
                              ? NetworkImage(userData['profilePicture'])
                              : const AssetImage('assets/default_profile.png') as ImageProvider,
                        ),
                        const SizedBox(height: 16),

                        // Username and Bio
                        Text(
                          userData['name'] ?? 'No name provided',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          userData['bio'] ?? 'No bio available yet.',
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),

                        // Follower/Following Counts with Navigation
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FollowersScreen(
                                      followers: userData['followers'] ?? [],
                                    ),
                                  ),
                                );
                              },
                              child: Column(
                                children: [
                                  Text(
                                    '$followersCount',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text('Followers'),
                                ],
                              ),
                            ),
                            const SizedBox(width: 30),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FollowingScreen(
                                      following: userData['following'] ?? [],
                                    ),
                                  ),
                                );
                              },
                              child: Column(
                                children: [
                                  Text(
                                    '$followingCount',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text('Following'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Follow/Unfollow Button
                        if (widget.userID != currentUserId) // Don't show button on own profile
                          ElevatedButton(
                            onPressed: _toggleFollow,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isFollowing ? Colors.red : Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(isFollowing ? 'Unfollow' : 'Follow'),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
