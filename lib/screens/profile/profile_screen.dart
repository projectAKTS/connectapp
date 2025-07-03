// lib/screens/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'edit_profile_screen.dart';
import '../consultation/consultation_booking_screen.dart';
import '../credits_store_screen.dart';
import '/services/boost_service.dart';
import '../Agora_Call_Screen.dart'; // ← for video call

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

  // ── FILTER STATE ─────────────────────────────────────────
  String selectedFilter = 'all';
  final Map<String, String?> filterMap = {
    'all':        null,
    'experience': 'Experience',
    'advice':     'Advice',
    'how-to':     'How-To',
    'lookingFor': 'Looking For...',  // exactly your Firestore tag
  };
  // ──────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _checkIfCurrentUser();
    _loadUserData();
  }

  void _checkIfCurrentUser() {
    final cur = FirebaseAuth.instance.currentUser;
    if (cur != null) isCurrentUser = cur.uid == widget.userID;
  }

  Future<void> _loadUserData() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userID)
        .get();
    if (!snap.exists) {
      setState(() => isLoading = false);
      return;
    }
    userData = snap.data()!;
    setState(() => isLoading = false);

    if (!isCurrentUser) {
      final cur = FirebaseAuth.instance.currentUser;
      if (cur != null) {
        final follow = await FirebaseFirestore.instance
            .collection('followers')
            .doc(widget.userID)
            .collection('userFollowers')
            .doc(cur.uid)
            .get();
        setState(() => isFollowing = follow.exists);
      }
    }
  }

  Future<void> _toggleFollow() async {
    final cur = FirebaseAuth.instance.currentUser;
    if (cur == null) return;
    final ref = FirebaseFirestore.instance
        .collection('followers')
        .doc(widget.userID)
        .collection('userFollowers')
        .doc(cur.uid);
    if (isFollowing) {
      await ref.delete();
      setState(() => isFollowing = false);
    } else {
      await ref.set({'timestamp': FieldValue.serverTimestamp()});
      setState(() => isFollowing = true);
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
    if (userData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('User not found!')),
      );
    }

    final boostedUntil = (userData!['boostedUntil'] as Timestamp?)?.toDate();
    final isBoosted =
        boostedUntil != null && boostedUntil.isAfter(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1) Header
            Center(
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage:
                        const AssetImage('assets/default_profile.png'),
                  ),
                  if (isBoosted)
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.orangeAccent,
                      child: Icon(Icons.star, color: Colors.white, size: 20),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              userData!['fullName'] ?? 'Unknown User',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              userData!['bio'] ?? 'No bio available',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),

            // 2) Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatColumn(
                  Icons.whatshot,
                  'Streak',
                  '${userData!['streakDays'] ?? 0} days',
                ),
                _buildStatColumn(
                  Icons.emoji_events,
                  'XP',
                  '${userData!['xpPoints'] ?? 0}',
                ),
                _buildStatColumn(
                  Icons.thumb_up,
                  'Helpful',
                  '${userData!['helpfulMarks'] ?? 0}',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3) Badges (only if your userData has a non-empty badges list)
            if (userData!.containsKey('badges') &&
                userData!['badges'] is List &&
                (userData!['badges'] as List).isNotEmpty) ...[
              const Text('Badges:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  // show up to 3
                  for (var i = 0;
                      i < (userData!['badges'] as List).length && i < 3;
                      i++)
                    Chip(
                      label:
                          Text((userData!['badges'] as List)[i].toString()),
                      backgroundColor: Colors.grey.shade100,
                    ),
                  // "+N more" tappable
                  if ((userData!['badges'] as List).length > 3)
                    ActionChip(
                      label: Text(
                          '+ ${(userData!['badges'] as List).length - 3} more'),
                      backgroundColor: Colors.grey.shade100,
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (_) => ListView(
                            padding: const EdgeInsets.all(16),
                            children:
                                (userData!['badges'] as List<dynamic>)
                                    .map((b) => ListTile(
                                          leading:
                                              const Icon(Icons.star_border),
                                          title: Text(b.toString()),
                                        ))
                                    .toList(),
                          ),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // 4) Featured Posts
            const Text('Featured Posts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 140,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .where('userID', isEqualTo: widget.userID)
                    .snapshots(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data?.docs ?? [];
                  docs.sort((a, b) {
                    final tA = (a['timestamp'] as Timestamp?)?.toDate() ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    final tB = (b['timestamp'] as Timestamp?)?.toDate() ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    return tB.compareTo(tA);
                  });
                  final featured = docs.take(3).toList();
                  if (featured.isEmpty) {
                    return const Center(child: Text('No featured posts yet.'));
                  }
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: featured.length,
                    itemBuilder: (c, i) {
                      final d =
                          featured[i].data()! as Map<String, dynamic>;
                      return Container(
                        width: 200,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          d['content'] ?? '',
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // 5) Filter Chips
            Wrap(
              spacing: 8,
              children: filterMap.keys.map((key) {
                final isSel = key == selectedFilter;
                final label = key == 'all' ? 'All' : filterMap[key]!;
                return ChoiceChip(
                  label: Text(label),
                  selected: isSel,
                  onSelected: (_) =>
                      setState(() => selectedFilter = key),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 6) Recent Activity
            const Text('Recent Activity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .where('userID', isEqualTo: widget.userID)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                var docs = snap.data?.docs ?? [];
                docs.sort((a, b) {
                  final tA = (a['timestamp'] as Timestamp?)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  final tB = (b['timestamp'] as Timestamp?)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  return tB.compareTo(tA);
                });

                // filter safely on tags
                final tag = filterMap[selectedFilter];
                final filtered = docs.where((doc) {
                  final data = doc.data()! as Map<String, dynamic>;
                  final tagsList = data.containsKey('tags') &&
                          data['tags'] is List
                      ? List<String>.from(data['tags'])
                      : <String>[];
                  return tag == null || tagsList.contains(tag);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No activity yet.'));
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (c, i) {
                    final d = filtered[i].data()! as Map<String, dynamic>;
                    final ts = d['timestamp'] as Timestamp?;
                    final date = ts?.toDate();
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text(d['content'] ?? ''),
                        subtitle: date != null
                            ? Text(DateFormat.yMMMd().format(date))
                            : null,
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: !isCurrentUser
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _toggleFollow,
                child: Text(isFollowing ? 'Unfollow' : 'Follow'),
              ),
            )
          : null,
    );
  }

  Widget _buildStatColumn(IconData icon, String label, String value) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: Colors.orangeAccent),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
        const SizedBox(height: 4),
        Text(value,
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
