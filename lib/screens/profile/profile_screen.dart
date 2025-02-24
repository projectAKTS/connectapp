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
    isCurrentUser = currentUserID == widget.userID;
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
              CircleAvatar(radius: 60, backgroundImage: AssetImage('assets/default_profile.png')),
              const SizedBox(height: 16),

              Text(userData!['fullName'] ?? 'N/A', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(userData!['bio'] ?? 'No bio available', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
              const SizedBox(height: 16),

              // 🔥 XP Points
              Text('XP Points: ${userData!['xpPoints'] ?? 0}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              // 🏆 Badges
              if (userData!['badges'] != null && (userData!['badges'] as List).isNotEmpty) ...[
                const Text('Badges:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: (userData!['badges'] as List).map<Widget>((badge) => Chip(label: Text(badge))).toList(),
                ),
              ],

              const SizedBox(height: 20),

              // 🔥 Active Perks
              if (userData!['activePerks'] != null) ...[
                const Text('Active Perks:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: userData!['activePerks'].entries.map<Widget>((perk) {
                    if (perk.value != null) {
                      return Chip(label: Text('${perk.key.replaceAll('_', ' ')}: Active'));
                    } else {
                      return const SizedBox.shrink();
                    }
                  }).toList(),
                ),
              ],

              const SizedBox(height: 20),

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
