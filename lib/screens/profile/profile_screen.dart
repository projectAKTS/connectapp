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
  bool isCurrentUser = false;

  @override
  void initState() {
    super.initState();
    _checkIfCurrentUser();
    fetchUserData();
  }

  void _checkIfCurrentUser() {
    String currentUserID = FirebaseAuth.instance.currentUser?.uid ?? '';
    isCurrentUser = currentUserID == widget.userID; // ✅ Check if viewing own profile
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

    if (errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(child: Text(errorMessage, style: const TextStyle(color: Colors.red))),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 🔹 Profile Image
              CircleAvatar(
                radius: 60,
                backgroundImage: AssetImage('assets/default_profile.png'),
              ),
              const SizedBox(height: 16),

              // 🔹 Full Name and Bio
              Text(userData!['fullName'] ?? 'N/A',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(userData!['bio'] ?? 'No bio available',
                  style: TextStyle(fontSize: 16, color: Colors.grey[700])),

              const SizedBox(height: 16),

              // 🔹 Journey Section
              if (userData!['careerJourney'] != null)
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Journey', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(userData!['careerJourney']),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // 🔹 Help Topics
              if (userData!['helpTopics'] != null &&
                  (userData!['helpTopics'] as List).isNotEmpty) ...[
                const Text('How You Can Help', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: (userData!['helpTopics'] as List)
                      .map<Widget>((topic) => Chip(
                            label: Text(topic),
                            backgroundColor: Colors.blue.shade100,
                          ))
                      .toList(),
                ),
              ],

              const SizedBox(height: 16),

              // 🔹 Interest Tags
              if (userData!['interestTags'] != null &&
                  (userData!['interestTags'] as List).isNotEmpty) ...[
                const Text('Interest Tags', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: (userData!['interestTags'] as List)
                      .map<Widget>((tag) => Chip(
                            label: Text('#$tag'),
                            backgroundColor: Colors.green.shade100,
                          ))
                      .toList(),
                ),
              ],

              const SizedBox(height: 20),

              // ✅ Only show Edit Profile button if it's **current user's profile**
              if (isCurrentUser)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
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
            ],
          ),
        ),
      ),
    );
  }
}
