// lib/screens/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'edit_profile_screen.dart';
import '../consultation/consultation_booking_screen.dart';
import '../credits_store_screen.dart';
import '/services/boost_service.dart';
import '../Agora_Call_Screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userID;
  const ProfileScreen({Key? key, required this.userID}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ScrollController _scrollController = ScrollController();
  late final Stream<QuerySnapshot> _featuredPostsStream;
  late final PageController _pageController;

  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isCurrentUser = false;
  bool isFollowing = false;

  String selectedFilter = 'all';
  final Map<String, String?> filterMap = {
    'all':        null,
    'experience': 'Experience',
    'advice':     'Advice',
    'how-to':     'How-To',
    'lookingFor': 'Looking For...',
  };

  @override
  void initState() {
    super.initState();
    _checkIfCurrentUser();
    _loadUserData();
    _featuredPostsStream = FirebaseFirestore.instance
        .collection('posts')
        .where('userID', isEqualTo: widget.userID)
        .snapshots();
    _pageController = PageController(viewportFraction: 0.8);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _checkIfCurrentUser() {
    final cur = FirebaseAuth.instance.currentUser;
    if (cur != null && cur.uid == widget.userID) {
      isCurrentUser = true;
    }
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
    userData = snap.data();
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

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    // main.dart’s auth listener will redirect to login screen
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
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (isCurrentUser)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Log out',
              onPressed: _signOut,
            ),
        ],
      ),
      body: SingleChildScrollView(
        key: const PageStorageKey('profileScroll'),
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ... [the rest of your existing widgets unmodified] ...
            // 1) Profile header + boost badge
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
                _buildStatColumn(Icons.whatshot, 'Streak',
                    '${userData!['streakDays'] ?? 0} days'),
                _buildStatColumn(Icons.emoji_events, 'XP',
                    '${userData!['xpPoints'] ?? 0}'),
                _buildStatColumn(Icons.thumb_up, 'Helpful',
                    '${userData!['helpfulMarks'] ?? 0}'),
              ],
            ),
            const SizedBox(height: 16),

            // 3) Badges
            if ((userData!['badges'] as List?)?.isNotEmpty ?? false) ...[
              const Text('Badges:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (var i = 0;
                      i < (userData!['badges'] as List).length && i < 3;
                      i++)
                    Chip(
                      label:
                          Text((userData!['badges'] as List)[i].toString()),
                      backgroundColor: Colors.grey.shade100,
                    ),
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
                            children: (userData!['badges'] as List)
                                .map((b) => ListTile(
                                      leading: const Icon(Icons.star_border),
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

            // 4) Featured Posts — stable stream & PageView
            const Text('Featured Posts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: StreamBuilder<QuerySnapshot>(
                stream: _featuredPostsStream,
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data?.docs ?? [];
                  docs.sort((a, b) {
                    final aTs = (a['timestamp'] as Timestamp?)?.toDate() ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    final bTs = (b['timestamp'] as Timestamp?)?.toDate() ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    return bTs.compareTo(aTs);
                  });
                  final featured = docs.take(3).toList();
                  if (featured.isEmpty) {
                    return const Center(child: Text('No featured posts yet.'));
                  }
                  return PageView.builder(
                    controller: _pageController,
                    itemCount: featured.length,
                    padEnds: false,
                    itemBuilder: (c, i) {
                      final data =
                          featured[i].data() as Map<String, dynamic>;
                      final date =
                          (data['timestamp'] as Timestamp?)?.toDate();
                      return Padding(
                        padding: EdgeInsets.only(
                          left: i == 0 ? 0 : 12,
                          right: i == featured.length - 1 ? 0 : 12,
                        ),
                        child: Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    data['content'] ?? '',
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                if (date != null)
                                  Text(
                                    DateFormat.yMMMd().format(date),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // 5) Filters
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: filterMap.length,
                itemBuilder: (ctx, i) {
                  final key = filterMap.keys.elementAt(i);
                  final label = key == 'all' ? 'All' : filterMap[key]!;
                  final isSelected = key == selectedFilter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: ValueKey(key),
                      label: Text(label),
                      selected: isSelected,
                      onSelected: (_) =>
                          setState(() => selectedFilter = key),
                      selectedColor: Colors.purple.shade100,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                          color: isSelected
                              ? Colors.purple
                              : Colors.grey.shade400),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // 6) Recent Activity
            const Text('Recent Activity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 300,
              child: StreamBuilder<QuerySnapshot>(
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
                    final aTs = (a['timestamp'] as Timestamp?)?.toDate() ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    final bTs = (b['timestamp'] as Timestamp?)?.toDate() ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    return bTs.compareTo(aTs);
                  });
                  final tag = filterMap[selectedFilter];
                  final filtered = docs.where((doc) {
                    final map = doc.data() as Map<String, dynamic>;
                    final tagsList = map['tags'] is List
                        ? List<String>.from(map['tags'])
                        : <String>[];
                    return tag == null || tagsList.contains(tag);
                  }).toList();
                  if (filtered.isEmpty) {
                    return const Center(child: Text('No activity yet.'));
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (c, i) {
                      final d = filtered[i].data() as Map<String, dynamic>;
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
