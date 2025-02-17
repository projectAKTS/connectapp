import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userID;

  const ProfileScreen({Key? key, required this.userID}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  String errorMessage = "";

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userID)
          .get();

      if (snapshot.exists) {
        setState(() {
          userData = snapshot.data() as Map<String, dynamic>;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = "No user found for userID: ${widget.userID}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Error fetching user data: $e";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: AssetImage('assets/default_profile.png'),
                ),
              ),
              const SizedBox(height: 16),

              Text('Name: ${userData!['fullName'] ?? 'N/A'}'),
              Text('Bio: ${userData!['bio'] ?? 'No bio available'}'),
              Text('Journey: ${userData!['careerJourney'] ?? 'Not provided'}'),

              const SizedBox(height: 16),

              // Help Topics
              if (userData!['helpTopics'] != null &&
                  (userData!['helpTopics'] as List).isNotEmpty) ...[
                const Text('Help Topics:', style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 8,
                  children: (userData!['helpTopics'] as List)
                      .map<Widget>((topic) => Chip(label: Text(topic)))
                      .toList(),
                ),
              ],

              const SizedBox(height: 16),

              // Interest Tags
              if (userData!['interestTags'] != null &&
                  (userData!['interestTags'] as List).isNotEmpty) ...[
                const Text('Interest Tags:', style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 8,
                  children: (userData!['interestTags'] as List)
                      .map<Widget>((tag) => Chip(label: Text('#$tag')))
                      .toList(),
                ),
              ],

              const SizedBox(height: 20),

              // ✅ Fix: Add back "Edit Profile" button
              Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final updatedData = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProfileScreen(userData: userData!),
                      ),
                    );

                    if (updatedData != null) {
                      setState(() {
                        userData!.addAll(updatedData);
                      });
                    }
                  },
                  child: const Text('Edit Profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
