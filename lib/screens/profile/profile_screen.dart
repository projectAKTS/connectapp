// lib/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:connect_app/utils/time_utils.dart';
import '../onboarding_screen.dart';
import '../chat/chat_screen.dart';
import 'package:connect_app/services/call_service.dart';

class ProfileScreen extends StatefulWidget {
  final String userID;
  const ProfileScreen({Key? key, required this.userID}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ScrollController _scrollController = ScrollController();
  late final Stream<QuerySnapshot> _postsStream; // all user posts
  late final PageController _pageController;

  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isCurrentUser = false;
  bool isFollowing = false;
  bool _followBusy = false;

  String selectedFilter = 'all';
  final Map<String, String?> filterMap = const {
    'all': null,
    'experience': 'experience',
    'advice': 'advice',
    'how-to': 'how-to',
    'lookingFor': 'looking for...',
  };

  // ---- tiny helpers
  void _log(String m) => debugPrint('👤 Profile[${widget.userID}] $m');
  String _s(dynamic v, [String fallback = '']) => v == null ? fallback : v.toString();
  int _i(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return fallback;
  }
  List<String> _stringList(dynamic v) =>
      (v is List) ? v.map((e) => e.toString()).toList() : const <String>[];

  @override
  void initState() {
    super.initState();
    final cur = FirebaseAuth.instance.currentUser;
    isCurrentUser = (cur != null && cur.uid == widget.userID);
    _loadUserData();

    // NOTE: no orderBy in query (avoids composite index); we sort in code.
    _postsStream = FirebaseFirestore.instance
        .collection('posts')
        .where('userID', isEqualTo: widget.userID)
        .snapshots();

    _pageController = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(widget.userID).get();
      if (!snap.exists) {
        setState(() {
          userData = null;
          isLoading = false;
        });
        return;
      }

      bool following = false;
      final cur = FirebaseAuth.instance.currentUser;
      if (!isCurrentUser && cur != null) {
        final followDoc = await FirebaseFirestore.instance
            .collection('followers')
            .doc(widget.userID)
            .collection('userFollowers')
            .doc(cur.uid)
            .get();
        following = followDoc.exists;
      }

      setState(() {
        userData = Map<String, dynamic>.from(snap.data() as Map);
        isFollowing = following;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _snack('Failed to load profile: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _toggleFollow() async {
    final cur = FirebaseAuth.instance.currentUser;
    if (cur == null) {
      _snack('Please log in to follow users.');
      return;
    }
    if (_followBusy) return;

    final ref = FirebaseFirestore.instance
        .collection('followers')
        .doc(widget.userID)
        .collection('userFollowers')
        .doc(cur.uid);

    final previous = isFollowing;

    setState(() {
      _followBusy = true;
      isFollowing = !previous; // optimistic UI
    });

    try {
      if (previous) {
        await ref.delete();
      } else {
        await ref.set({'timestamp': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      }
    } catch (e) {
      setState(() => isFollowing = previous);
      _snack('Follow action failed. Please try again.');
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  Future<void> _startCall({required bool isVideo}) async {
    final otherName = _s(userData?['fullName'], 'Unknown');
    await CallService().startCall(
      context,
      toUid: widget.userID,
      toName: otherName,
      isVideo: isVideo,
    );
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  // ---------- Connect sheet ----------
  void _openConnectSheet() {
    final otherName = (userData?['fullName'] as String?) ?? 'Unknown';
    final ratePerMinute =
        (userData?['ratePerMinute'] is num) ? (userData!['ratePerMinute'] as num).toInt() : 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        Widget item(IconData icon, String label, VoidCallback onTap) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFE9E9EF),
              child: Icon(icon, color: Colors.black87),
            ),
            title: Text(label, style: const TextStyle(color: Colors.black87)),
            onTap: () {
              Navigator.pop(context);
              onTap();
            },
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 10),
              item(Icons.event_available_outlined, 'Book a call', () {
                Navigator.of(context).pushNamed(
                  '/consultation',
                  arguments: {
                    'targetUserId': widget.userID,
                    'targetUserName': otherName,
                    'ratePerMinute': ratePerMinute,
                  },
                );
              }),
              item(Icons.chat_bubble_outline, 'Message', () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ChatScreen(otherUserId: widget.userID)),
                );
              }),
              item(Icons.call, 'Audio call', () => _startCall(isVideo: false)),
              item(Icons.videocam, 'Video call', () => _startCall(isVideo: true)),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ---------- UI helpers (hard-contrast) ----------
  static const _bg = Colors.white;
  static const _text = Colors.black87;
  static const _muted = Colors.black54;
  static const _card = Colors.white;
  static const _pill = Color(0xFFF1F1F3);
  static const _border = Color(0xFFE6E2DD);

  Widget _softCard({required Widget child, EdgeInsets padding = const EdgeInsets.all(16)}) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          )
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }

  Widget _pillButton({
    required Widget child,
    VoidCallback? onTap,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  }) {
    return Material(
      color: _pill,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: DefaultTextStyle.merge(
            style: const TextStyle(
              color: _text,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _badgeChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _pill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, color: _text)),
    );
  }

  ImageProvider _avatarProvider(Map<String, dynamic> data) {
    final url = (data['profilePicture'] ?? '') as String? ?? '';
    if (url.isNotEmpty) return NetworkImage(url);
    return const AssetImage('assets/default_profile.png');
  }

  @override
  Widget build(BuildContext context) {
    final debugTheme = Theme.of(context).copyWith(
      scaffoldBackgroundColor: _bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: _text,
        iconTheme: IconThemeData(color: _text),
        titleTextStyle: TextStyle(color: _text, fontSize: 20, fontWeight: FontWeight.w700),
      ),
      textTheme: Theme.of(context).textTheme.apply(bodyColor: _text, displayColor: _text),
      snackBarTheme: const SnackBarThemeData(contentTextStyle: TextStyle(color: Colors.white)),
    );

    if (isLoading) {
      return Theme(
        data: debugTheme,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (userData == null) {
      return Theme(
        data: debugTheme,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
          ),
          body: const Center(
            child: Text('User not found!', style: TextStyle(color: _muted)),
          ),
        ),
      );
    }

    final boostedUntil = parseFirestoreTimestamp(userData!['boostedUntil']);
    final isBoosted = boostedUntil != null && boostedUntil.isAfter(DateTime.now());

    final fullName = _s(userData!['fullName'], 'Unknown User');
    final bio = _s(userData!['bio']);
    final badges = _stringList(userData!['badges']);
    final streakDays = _i(userData!['streakDays']);
    final xpPoints = _i(userData!['xpPoints']);
    final helpfulMarks = _i(userData!['helpfulMarks']);

    return Theme(
      data: debugTheme,
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
          title: const Text('Profile'),
          actions: [
            if (isCurrentUser) ...[
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: "Edit Profile",
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Log out',
                onPressed: _signOut,
              ),
            ],
          ],
        ),
        body: SingleChildScrollView(
          key: const PageStorageKey('profileScroll'),
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar + name + bio
              Center(
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: const Color(0xFFE9E9EF),
                      foregroundColor: Colors.black54,
                      backgroundImage: _avatarProvider(userData!),
                    ),
                    if (isBoosted)
                      Container(
                        margin: const EdgeInsets.only(right: 6, top: 6),
                        decoration: const BoxDecoration(
                          color: _pill,
                          shape: BoxShape.circle,
                        ),
                        child: const CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.orange,
                          child: Icon(Icons.star, color: Colors.white, size: 18),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                fullName,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(bio, textAlign: TextAlign.center, style: const TextStyle(color: _muted)),
              ],

              if (isCurrentUser) ...[
                const SizedBox(height: 12),
                Center(
                  child: _pillButton(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                      );
                    },
                    child: Row(mainAxisSize: MainAxisSize.min, children: const [
                      Icon(Icons.edit_outlined, size: 18, color: _text),
                      SizedBox(width: 8),
                      Text('Edit profile'),
                    ]),
                  ),
                ),
              ],

              // ---------- Connect (single button) ----------
              if (!isCurrentUser) ...[
                const SizedBox(height: 12),
                Center(
                  child: _pillButton(
                    onTap: _openConnectSheet,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    child: Row(mainAxisSize: MainAxisSize.min, children: const [
                      Icon(Icons.flash_on_outlined, size: 18, color: _text),
                      SizedBox(width: 8),
                      Text('Connect'),
                    ]),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // ---------- Stats (merged cards) ----------
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.local_fire_department_rounded,
                      label: 'Streak',
                      value: '$streakDays days',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.emoji_events_outlined,
                      label: 'XP',
                      value: '$xpPoints',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.thumb_up_alt_outlined,
                      label: 'Helpful',
                      value: '$helpfulMarks',
                    ),
                  ),
                ],
              ),

              if (badges.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Badges',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < badges.length && i < 3; i++) _badgeChip(badges[i]),
                    if (badges.length > 3)
                      _pillButton(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: _card,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                            ),
                            builder: (_) => ListView(
                              padding: const EdgeInsets.all(16),
                              children: badges
                                  .map((b) => ListTile(
                                        leading: const Icon(Icons.star_border, color: _text),
                                        title: Text(b, style: const TextStyle(color: _text)),
                                      ))
                                  .toList(),
                            ),
                          );
                        },
                        child: Text('+ ${badges.length - 3} more'),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 16),
              const Text('Featured Posts',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              SizedBox(
                height: 190,
                child: StreamBuilder<QuerySnapshot>(
                  stream: _postsStream,
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Text('Error: ${snap.error}', style: const TextStyle(color: Colors.red)),
                      );
                    }
                    final all = (snap.data?.docs ?? []).toList();
                    // sort by timestamp desc
                    all.sort((a, b) {
                      final aTs = parseFirestoreTimestamp(a['timestamp']) ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      final bTs = parseFirestoreTimestamp(b['timestamp']) ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      return bTs.compareTo(aTs);
                    });
                    final featured = all.take(3).toList();
                    if (featured.isEmpty) {
                      return const Center(
                        child: Text('No featured posts yet.', style: TextStyle(color: _muted)),
                      );
                    }
                    return PageView.builder(
                      controller: _pageController,
                      itemCount: featured.length,
                      padEnds: false,
                      itemBuilder: (c, i) {
                        final data = featured[i].data() as Map<String, dynamic>;
                        final date = parseFirestoreTimestamp(data['timestamp']);
                        return Padding(
                          padding: EdgeInsets.only(
                            left: i == 0 ? 0 : 10,
                            right: i == featured.length - 1 ? 0 : 10,
                          ),
                          child: _softCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    _s(data['content']),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14, height: 1.35),
                                  ),
                                ),
                                if (date != null)
                                  Text(
                                    DateFormat.yMMMd().format(date),
                                    style: const TextStyle(fontSize: 12, color: _muted),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                height: 44,
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
                        label: Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSelected ? _text : _text.withOpacity(0.85),
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) => setState(() => selectedFilter = key),
                        selectedColor: _pill,
                        backgroundColor: _card,
                        side: const BorderSide(color: _border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              const Text('Recent Activity',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              SizedBox(
                height: 320,
                child: StreamBuilder<QuerySnapshot>(
                  stream: _postsStream,
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Text('Error: ${snap.error}', style: const TextStyle(color: Colors.red)),
                      );
                    }

                    var docs = (snap.data?.docs ?? []).toList()
                      ..sort((a, b) {
                        final aTs = parseFirestoreTimestamp(a['timestamp']) ??
                            DateTime.fromMillisecondsSinceEpoch(0);
                        final bTs = parseFirestoreTimestamp(b['timestamp']) ??
                            DateTime.fromMillisecondsSinceEpoch(0);
                        return bTs.compareTo(aTs);
                      });

                    final tag = filterMap[selectedFilter];
                    final filtered = docs.where((doc) {
                      final map = doc.data() as Map<String, dynamic>;
                      final tagsList =
                          _stringList(map['tags']).map((e) => e.toLowerCase()).toList();
                      return tag == null || tagsList.contains(tag.toLowerCase());
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text('No activity yet.', style: TextStyle(color: _muted)),
                      );
                    }

                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (c, i) {
                        final d = filtered[i].data() as Map<String, dynamic>;
                        final dt = parseFirestoreTimestamp(d['timestamp']);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _softCard(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(_s(d['content'])),
                              subtitle: dt != null
                                  ? Text(DateFormat.yMMMd().format(dt),
                                      style: const TextStyle(color: _muted))
                                  : null,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),

        // Follow button (bottom)
        bottomNavigationBar: !isCurrentUser
            ? SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: AbsorbPointer(
                  absorbing: _followBusy,
                  child: Opacity(
                    opacity: _followBusy ? 0.6 : 1,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _toggleFollow,
                      child: Text(isFollowing ? 'UNFOLLOW' : 'FOLLOW'),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

// ---------- Small stat card used above ----------
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E2DD)),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.black87),
            const SizedBox(width: 8),
            const Text(''),
            Text(label, style: const TextStyle(color: Colors.black54)),
          ]),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ],
      ),
    );
  }
}
