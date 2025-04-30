// lib/screens/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'edit_profile_screen.dart';
import '../consultation/consultation_booking_screen.dart';
import '../credits_store_screen.dart';
import '/services/boost_service.dart';
import '../Agora_Call_Screen.dart'; // ← added for video call

class ProfileScreen extends StatefulWidget {
  final String userID;

  const ProfileScreen({Key? key, required this.userID}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isCurrentUser = false;
  bool isFollowing = false;

  @override
  void initState() {
    super.initState();
    _checkIfCurrentUser();
    fetchUserData();
  }

  void _checkIfCurrentUser() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      setState(() {
        isCurrentUser = currentUser.uid == widget.userID;
      });
    }
  }

  Future<void> fetchUserData() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userID)
          .get();

      if (snapshot.exists) {
        setState(() {
          userData = snapshot.data() as Map<String, dynamic>;
          isLoading = false;
        });

        if (!isCurrentUser) {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            final followDoc = await FirebaseFirestore.instance
                .collection('followers')
                .doc(widget.userID)
                .collection('userFollowers')
                .doc(currentUser.uid)
                .get();

            setState(() {
              isFollowing = followDoc.exists;
            });
          }
        }
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
      print('Error fetching user data: $e');
    }
  }

  Future<void> toggleFollow() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final followRef = FirebaseFirestore.instance
        .collection('followers')
        .doc(widget.userID)
        .collection('userFollowers');

    if (isFollowing) {
      await followRef.doc(currentUser.uid).delete();
    } else {
      await followRef.doc(currentUser.uid).set({
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    setState(() {
      isFollowing = !isFollowing;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (userData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('User not found!')),
      );
    }

    // ─── determine boost state ───────────────────────────────────────────
    final boostedUntil = (userData!['boostedUntil'] as Timestamp?)?.toDate();
    final isBoosted = boostedUntil != null && boostedUntil.isAfter(DateTime.now());
    // ─────────────────────────────────────────────────────────────────────

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile Picture with boost badge
            Stack(alignment: Alignment.topRight, children: [
              CircleAvatar(
                radius: 60,
                backgroundImage: const AssetImage('assets/default_profile.png'),
              ),
              if (isBoosted)
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.orangeAccent,
                  child: Icon(Icons.star, color: Colors.white, size: 20),
                ),
            ]),
            const SizedBox(height: 16),

            // Name & Bio
            Text(
              userData!['fullName'] ?? 'Unknown User',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              userData!['bio'] ?? 'No bio available',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),

            // Follow/Unfollow (Other Users)
            if (!isCurrentUser)
              ElevatedButton(
                onPressed: toggleFollow,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(isFollowing ? 'Unfollow' : 'Follow'),
              ),
            const SizedBox(height: 16),

            // Book Consultation (Other Users)
            if (!isCurrentUser)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ConsultationBookingScreen(
                        targetUserId: widget.userID,
                        targetUserName: userData!['fullName'] ?? 'Unknown User',
                        ratePerMinute: userData!['ratePerMinute'] ?? 0,
                      ),
                    ),
                  );
                },
                child: const Text('Book Consultation'),
              ),
            const SizedBox(height: 16),

            // ─── NEW: Video Call Button (Other Users) ─────────────────────────
            if (!isCurrentUser)
              ElevatedButton.icon(
                icon: const Icon(Icons.video_call),
                label: const Text('Start Video Call'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, '/video_call');
                },
              ),
            const SizedBox(height: 16),
            // ───────────────────────────────────────────────────────────────────

            // My Consultations (Current User)
            if (isCurrentUser)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, '/my_consultations');
                },
                child: const Text('My Consultations'),
              ),
            const SizedBox(height: 16),

            // Free Minutes & Buy Credits (Current User)
            if (isCurrentUser) ...[
              Text(
                'Minutes Left: ${userData!['freeConsultationMinutes'] ?? 0}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/credits'),
                child: const Text('Buy More Minutes'),
              ),
              const SizedBox(height: 16),
            ],

            // XP Points
            Text(
              'XP Points: ${userData!['xpPoints'] ?? 0}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Streak Days
            Text(
              '🔥 Streak: ${userData!['streakDays'] ?? 0} days',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Helpful Marks
            Text(
              '👍 Helpful Marks: ${userData!['helpfulMarks'] ?? 0}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Premium Status
            if (userData!['premiumStatus'] != null && userData!['premiumStatus'] != 'none') ...[
              const Text('Premium Status:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(
                '${userData!['premiumStatus']}',
                style: const TextStyle(fontSize: 16, color: Colors.blueAccent),
              ),
              if (userData!['premiumExpiresAt'] != null)
                Text(
                  'Expires: ${DateFormat.yMMMd().format((userData!['premiumExpiresAt'] as Timestamp).toDate())}',
                  style: const TextStyle(fontSize: 16, color: Colors.blueAccent),
                ),
              const SizedBox(height: 8),
            ],

            // Trial Used
            Text(
              'Trial Used: ${userData!['trialUsed'] == true ? 'Yes' : 'No'}',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),

            // Interests
            if (userData!['interestTags'] != null && (userData!['interestTags'] as List).isNotEmpty) ...[
              const Text('Interests:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: (userData!['interestTags'] as List)
                    .map<Widget>((interest) => Chip(label: Text(interest)))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Badges
            if (userData!['badges'] != null && (userData!['badges'] as List).isNotEmpty) ...[
              const Text('🏅 Badges:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: (userData!['badges'] as List)
                    .map<Widget>((badge) => Chip(label: Text(badge)))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Boost Profile (Current User)
            if (isCurrentUser)
              ElevatedButton(
                onPressed: () => BoostService.boostProfile(widget.userID, 24),
                child: const Text('Boost My Profile'),
              ),

            // Edit Profile (Current User)
            if (isCurrentUser)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) {
                    Navigator.pushNamed(context, '/login');
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProfileScreen(userData: userData!),
                      ),
                    );
                  }
                },
                child: const Text('Edit Profile'),
              ),
          ],
        ),
      ),
    );
  }
}
