// lib/screens/profile/profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:connect_app/utils/time_utils.dart';
import '../posts/post_detail_screen.dart';
import 'edit_profile_screen.dart';
import 'package:connect_app/services/call_service.dart';
import 'package:connect_app/theme/tokens.dart';
import 'package:connect_app/widgets/full_screen_back_gesture.dart';
import 'package:connect_app/screens/profile/follow_list_screen.dart';
import 'package:connect_app/screens/messages/messages_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userID;
  const ProfileScreen({Key? key, required this.userID}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ScrollController _scrollController = ScrollController();
  late final Stream<QuerySnapshot> _postsStream;
  late final PageController _pageController;

  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isCurrentUser = false;
  bool isFollowing = false;
  bool _followBusy = false;

  // Horizontal swipe-back helpers
  double? _dragStartX;
  bool _dragFromEdge = false;

  // ✅ prevent multiple pops (fixes _debugLocked)
  bool _popQueued = false;

  // ---- Filters (match Create Post templates) ----
  // label -> slug
  final Map<String, String?> _filters = const {
    'All': null,
    'Quick': 'quick',
    'Experience': 'experience',
    'Advice Request': 'advice',
    'How-To Guide': 'how-to',
    'Lessons Learned': 'lessons',
  };
  String _selectedFilterLabel = 'All';

  bool _bioExpanded = false;

  // helpers
  String _s(dynamic v, [String fallback = '']) =>
      v == null ? fallback : v.toString();
  int _i(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return fallback;
  }

  int _unreadValue(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim()) ?? 0;
    return 0;
  }

  List<String> _stringList(dynamic v) =>
      (v is List) ? v.map((e) => e.toString()).toList() : const <String>[];

  @override
  void initState() {
    super.initState();
    final cur = FirebaseAuth.instance.currentUser;
    isCurrentUser = (cur != null && cur.uid == widget.userID);

    _loadUserData();

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
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userID)
          .get();
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
      _snack('Failed to load profile.');
    }
  }

  // Pull-to-refresh handler
  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    await _loadUserData();
    await Future.delayed(const Duration(milliseconds: 350));
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
    final myUserRef =
        FirebaseFirestore.instance.collection('users').doc(cur.uid);

    final previous = isFollowing;

    setState(() {
      _followBusy = true;
      isFollowing = !previous; // optimistic UI
    });

    try {
      if (previous) {
        await ref.delete();
        await myUserRef.set({
          'following': FieldValue.arrayRemove([widget.userID])
        }, SetOptions(merge: true));
      } else {
        await ref.set({'timestamp': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
        await myUserRef.set({
          'following': FieldValue.arrayUnion([widget.userID])
        }, SetOptions(merge: true));
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

    // ✅ Always start calls from ROOT context (prevents tab-navigator side effects)
    final rootCtx = Navigator.of(context, rootNavigator: true).context;

    await CallService().startCall(
      rootCtx,
      toUid: widget.userID,
      toName: otherName,
      isVideo: isVideo,
    );
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;

    // ✅ Auth flows always on ROOT navigator
    Navigator.of(context, rootNavigator: true)
        .pushNamedAndRemoveUntil('/login', (route) => false);
  }

  void _openConnectSheet() {
    final otherName = (userData?['fullName'] as String?) ?? 'Unknown';
    final ratePerMinute = (userData?['ratePerMinute'] is num)
        ? (userData!['ratePerMinute'] as num).toInt()
        : 0;

    final rootNav = Navigator.of(context, rootNavigator: true);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetCtx) {
        Widget item(IconData icon, String label, VoidCallback onTap) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.button,
              foregroundColor: AppColors.text,
              child: Icon(icon),
            ),
            title: Text(label, style: const TextStyle(color: AppColors.text)),
            onTap: () {
              Navigator.pop(sheetCtx);
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
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 10),

              // ✅ Global route -> ROOT
              item(Icons.event_available_outlined, 'Book a call', () {
                rootNav.pushNamed(
                  '/consultation',
                  arguments: {
                    'targetUserId': widget.userID,
                    'targetUserName': otherName,
                    'ratePerMinute': ratePerMinute,
                  },
                );
              }),

              // ✅ Global route -> ROOT
              item(Icons.chat_bubble_outline, 'Message', () {
                rootNav.pushNamed(
                  '/chat',
                  arguments: {
                    'otherUserId': widget.userID,
                    'otherUserName': otherName,
                    'otherUserAvatar':
                        (userData?['profilePicture'] ?? '').toString(),
                  },
                );
              }),

              item(Icons.call, 'Audio call', () => _startCall(isVideo: false)),
              item(Icons.videocam, 'Video call',
                  () => _startCall(isVideo: true)),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ---------- Horizontal swipe-back handlers ----------
  void _handleHorizontalDragStart(DragStartDetails details) {
    if (Platform.isIOS) return; // ✅ iOS already has native swipe-back
    _dragStartX = details.globalPosition.dx;
    _dragFromEdge = (_dragStartX ?? 0) < 32.0;
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (Platform.isIOS) return; // ✅ prevent double-gesture pop on iOS
    if (!_dragFromEdge) return;

    final nav = Navigator.of(context);
    if (!nav.canPop()) return;
    if (_popQueued) return;

    if (details.primaryDelta != null && details.primaryDelta! > 16) {
      _dragFromEdge = false;
      _popQueued = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        nav.maybePop();
        _popQueued = false;
      });
    }
  }

  // ---------- UI helpers ----------
  Widget _softCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border:
            const Border.fromBorderSide(BorderSide(color: AppColors.border)),
        boxShadow: const [AppShadows.soft],
      ),
      child: Padding(padding: padding, child: child),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _badgeChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.button,
        borderRadius: BorderRadius.circular(10),
        border:
            const Border.fromBorderSide(BorderSide(color: AppColors.border)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
      ),
    );
  }

  ImageProvider _avatarProvider(Map<String, dynamic> data) {
    final url = (data['profilePicture'] ?? '') as String? ?? '';
    if (url.isNotEmpty) return NetworkImage(url);
    return const AssetImage('assets/default_profile.png');
  }

  // ====== Parsing helpers ======
  String? _firstBoldLineLabel(String content) {
    final lines = content.split('\n');
    int idx = 0;
    while (idx < lines.length && lines[idx].trim().isEmpty) idx++;
    if (idx >= lines.length) return null;
    final m = RegExp(r'^\*\*(.+?)\*\*$').firstMatch(lines[idx].trim());
    return m?.group(1);
  }

  (String slug, String badgeText, String body) _classifyPost(
      Map<String, dynamic> map) {
    final rawContent = (map['content'] ?? '').toString();

    final lblFromContent = _firstBoldLineLabel(rawContent);
    if (lblFromContent != null &&
        lblFromContent.toLowerCase().endsWith(' post')) {
      final lower = lblFromContent.toLowerCase();

      String slug;
      if (lower.contains('advice')) {
        slug = 'advice';
      } else if (lower.contains('how')) {
        slug = 'how-to';
      } else if (lower.contains('lesson')) {
        slug = 'lessons';
      } else if (lower.contains('experience')) {
        slug = 'experience';
      } else if (lower.contains('quick')) {
        slug = 'quick';
      } else {
        slug = 'quick';
      }

      final lines = rawContent.split('\n');
      int idx = 0;
      while (idx < lines.length && lines[idx].trim().isEmpty) idx++;
      if (idx < lines.length) {
        lines.removeAt(idx);
        if (idx < lines.length && lines[idx].trim().isEmpty) {
          lines.removeAt(idx);
        }
      }
      final body = lines.join('\n').trimLeft();
      return (slug, lblFromContent, body);
    }

    return ('quick', 'Quick Post', rawContent);
  }

  TextSpan _mdSpan(String text) {
    const base = TextStyle(fontSize: 15, height: 1.35, color: AppColors.text);
    const strong = TextStyle(
      fontSize: 15,
      height: 1.35,
      color: AppColors.text,
      fontWeight: FontWeight.w700,
    );

    final spans = <TextSpan>[];
    int i = 0;
    while (i < text.length) {
      final start = text.indexOf('**', i);
      if (start == -1) {
        spans.add(TextSpan(text: text.substring(i), style: base));
        break;
      }
      if (start > i) {
        spans.add(TextSpan(text: text.substring(i, start), style: base));
      }
      final end = text.indexOf('**', start + 2);
      if (end == -1) {
        spans.add(TextSpan(text: text.substring(start), style: base));
        break;
      }
      spans.add(TextSpan(text: text.substring(start + 2, end), style: strong));
      i = end + 2;
    }
    return TextSpan(children: spans, style: base);
  }

  Widget _postTypeBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  // ========= Account row (new) =========
  Widget _accountRow({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? iconBg,
    Color? iconFg,
    int? badgeCount,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg ?? AppColors.button,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(icon, color: iconFg ?? AppColors.text),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (badgeCount != null && badgeCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '+$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nav = Navigator.of(context);
    final canPop = nav.canPop();
    Widget wrap(Widget child) => FullScreenBackGesture(child: child);

    final theme = Theme.of(context).copyWith(
      scaffoldBackgroundColor: AppColors.canvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        foregroundColor: AppColors.text,
        iconTheme: IconThemeData(color: AppColors.text),
        titleTextStyle: TextStyle(
          color: AppColors.text,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: Theme.of(context).textTheme.apply(
            bodyColor: AppColors.text,
            displayColor: AppColors.text,
          ),
      snackBarTheme: const SnackBarThemeData(
        contentTextStyle: TextStyle(color: Colors.white),
      ),
    );

    if (isLoading) {
      return wrap(Theme(
        data: theme,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            leading:
                canPop ? BackButton(onPressed: () => nav.maybePop()) : null,
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
      ));
    }

    if (userData == null) {
      return wrap(Theme(
        data: theme,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            leading:
                canPop ? BackButton(onPressed: () => nav.maybePop()) : null,
          ),
          body: const Center(
            child: Text('User not found!',
                style: TextStyle(color: AppColors.muted)),
          ),
        ),
      ));
    }

    final boostedUntil = parseFirestoreTimestamp(userData!['boostedUntil']);
    final isBoosted =
        boostedUntil != null && boostedUntil.isAfter(DateTime.now());

    final fullName = _s(userData!['fullName'], 'Unknown User');
    final bio = _s(userData!['bio']);
    final badges = _stringList(userData!['badges']);
    final streakDays = _i(userData!['streakDays']);
    final xpPoints = _i(userData!['xpPoints']);
    final helpfulMarks = _i(userData!['helpfulMarks']);

    // For Account section status (safe defaults)
    final premiumStatus = _s(userData!['premiumStatus']);
    final premiumExpiresAt =
        parseFirestoreTimestamp(userData!['premiumExpiresAt']);
    final hasCard = _s(userData!['defaultPaymentMethodId']).isNotEmpty;

    String premiumSubtitle() {
      if (premiumStatus.isEmpty) return 'Not active';
      final exp = premiumExpiresAt != null
          ? DateFormat.yMMMd().format(premiumExpiresAt)
          : null;
      return exp == null ? premiumStatus : '$premiumStatus • Expires $exp';
    }

    return wrap(Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          leading: canPop ? BackButton(onPressed: () => nav.maybePop()) : null,
          title: const Text('Profile'),
          actions: [
            if (isCurrentUser) ...[
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: "Edit Profile",
                onPressed: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => EditProfileScreen(userData: userData!),
                    ),
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
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart:
              Platform.isIOS ? null : _handleHorizontalDragStart,
          onHorizontalDragUpdate:
              Platform.isIOS ? null : _handleHorizontalDragUpdate,
          child: RefreshIndicator.adaptive(
            onRefresh: _onRefresh,
            edgeOffset: 0,
            displacement: 56,
            child: SingleChildScrollView(
              key: const PageStorageKey('profileScroll'),
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Avatar
                  Center(
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        CircleAvatar(
                          radius: 56,
                          backgroundColor: AppColors.avatarBg,
                          foregroundColor: AppColors.avatarFg,
                          backgroundImage: _avatarProvider(userData!),
                        ),
                        if (isBoosted)
                          Container(
                            margin: const EdgeInsets.only(right: 6, top: 6),
                            decoration: const BoxDecoration(
                              color: AppColors.button,
                              shape: BoxShape.circle,
                            ),
                            child: const CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.orange,
                              child: Icon(Icons.star,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    fullName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w800),
                  ),

                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _ExpandableBio(
                      text: bio,
                      expanded: _bioExpanded,
                      onToggle: () =>
                          setState(() => _bioExpanded = !_bioExpanded),
                    ),
                  ],

                  // Follow / Connect for other users
                  if (!isCurrentUser) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: AbsorbPointer(
                            absorbing: _followBusy,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 160),
                              child: isFollowing
                                  ? _OutlinedActionButton(
                                      key: const ValueKey('following-pill'),
                                      icon: Icons.check_circle,
                                      label: 'Following',
                                      onTap: _toggleFollow,
                                    )
                                  : _FilledActionButton(
                                      key: const ValueKey('follow-pill'),
                                      icon: Icons.person_add_alt_1,
                                      label: 'Follow',
                                      onTap: _toggleFollow,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _OutlinedActionButton(
                            icon: Icons.flash_on_outlined,
                            label: 'Connect',
                            onTap: _openConnectSheet,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Stats
                  _softCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: _StatsStrip(
                      streakText: '$streakDays days',
                      xpText: '$xpPoints',
                      helpfulText: '$helpfulMarks',
                    ),
                  ),

                  // ✅ Account hub (ONLY for current user)
                  if (isCurrentUser) ...[
                    const SizedBox(height: 16),
                    _sectionTitle('Social'),
                    _softCard(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      child: Column(
                        children: [
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('followers')
                                .doc(widget.userID)
                                .collection('userFollowers')
                                .snapshots(),
                            builder: (context, followersSnap) {
                              final followersCount =
                                  followersSnap.data?.docs.length ?? 0;
                              return _accountRow(
                                icon: Icons.group_outlined,
                                title: 'Followers',
                                subtitle: '$followersCount people',
                                onTap: () {
                                  Navigator.of(context).push(
                                    CupertinoPageRoute(
                                      builder: (_) => FollowListScreen(
                                        type: FollowListType.followers,
                                        userId: widget.userID,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          const Divider(height: 1, color: AppColors.border),
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(widget.userID)
                                .snapshots(),
                            builder: (context, meSnap) {
                              final me = meSnap.data?.data() ??
                                  const <String, dynamic>{};
                              final followingCount = (me['following'] is List)
                                  ? (me['following'] as List).length
                                  : 0;
                              return _accountRow(
                                icon: Icons.person_add_alt_1_outlined,
                                title: 'Following',
                                subtitle: '$followingCount people',
                                onTap: () {
                                  Navigator.of(context).push(
                                    CupertinoPageRoute(
                                      builder: (_) => FollowListScreen(
                                        type: FollowListType.following,
                                        userId: widget.userID,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          const Divider(height: 1, color: AppColors.border),
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(FirebaseAuth.instance.currentUser?.uid ??
                                    widget.userID)
                                .snapshots(),
                            builder: (context, userSnap) {
                              final d = userSnap.data?.data()
                                      as Map<String, dynamic>? ??
                                  const <String, dynamic>{};
                              final lastSeen = parseFirestoreTimestamp(
                                  d['lastMessagesSeenAt']);
                              final directUnread = _unreadValue(
                                d['unreadMessagesCount'],
                              );
                              final myUid =
                                  FirebaseAuth.instance.currentUser?.uid ??
                                      widget.userID;

                              return StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('chats')
                                    .where('participants', arrayContains: myUid)
                                    .snapshots(),
                                builder: (context, participantsSnap) {
                                  return StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('chats')
                                        .where('users', arrayContains: myUid)
                                        .snapshots(),
                                    builder: (context, usersSnap) {
                                      final merged =
                                          <String, Map<String, dynamic>>{};
                                      if (participantsSnap.hasData) {
                                        for (final doc
                                            in participantsSnap.data!.docs) {
                                          merged[doc.id] = (doc.data()
                                                  as Map<String, dynamic>? ??
                                              const <String, dynamic>{});
                                        }
                                      }
                                      if (usersSnap.hasData) {
                                        for (final doc
                                            in usersSnap.data!.docs) {
                                          merged[doc.id] = (doc.data()
                                                  as Map<String, dynamic>? ??
                                              const <String, dynamic>{});
                                        }
                                      }

                                      var unread = directUnread;
                                      final conversationCount = merged.length;
                                      if (unread <= 0) {
                                        for (final m in merged.values) {
                                          final unreadBy = m['unreadBy'];
                                          if (unreadBy is Map) {
                                            final value =
                                                _unreadValue(unreadBy[myUid]);
                                            if (value > 0) {
                                              unread += value;
                                              continue;
                                            }
                                          }
                                          final updated =
                                              parseFirestoreTimestamp(
                                                      m['updatedAt']) ??
                                                  parseFirestoreTimestamp(
                                                      m['lastMessageAt']);
                                          final author =
                                              (m['lastMessageAuthorId'] ?? '')
                                                  .toString();
                                          if (updated != null &&
                                              author != myUid &&
                                              (lastSeen == null ||
                                                  updated.isAfter(lastSeen))) {
                                            unread += 1;
                                          }
                                        }
                                      }

                                      return _accountRow(
                                        icon: Icons.chat_bubble_outline_rounded,
                                        title: 'Messages',
                                        subtitle: conversationCount > 0
                                            ? '$conversationCount conversations'
                                            : 'Open conversations',
                                        badgeCount: unread,
                                        onTap: () {
                                          Navigator.of(context).push(
                                            CupertinoPageRoute(
                                              builder: (_) => MessagesScreen(
                                                userId: myUid,
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                          const Divider(height: 1, color: AppColors.border),
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(widget.userID)
                                .snapshots(),
                            builder: (context, userSnap) {
                              DateTime? lastSeen;
                              if (userSnap.hasData) {
                                final d = userSnap.data!.data()
                                    as Map<String, dynamic>?;
                                lastSeen = parseFirestoreTimestamp(
                                    d?['lastConsultationsSeenAt']);
                              }

                              return StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('consultations')
                                    .where('participants',
                                        arrayContains: widget.userID)
                                    .snapshots(),
                                builder: (context, consultSnap) {
                                  int recentCount = 0;
                                  if (consultSnap.hasData) {
                                    for (final doc in consultSnap.data!.docs) {
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      final ts = parseFirestoreTimestamp(
                                          data['timestamp']);
                                      if (ts == null) continue;
                                      if (lastSeen == null ||
                                          ts.isAfter(lastSeen)) {
                                        recentCount++;
                                      }
                                    }
                                  }

                                  return _accountRow(
                                    icon: Icons.event_note_outlined,
                                    title: 'My consultations',
                                    subtitle: 'Upcoming & past sessions',
                                    badgeCount: recentCount,
                                    onTap: () {
                                      Navigator.of(context, rootNavigator: true)
                                          .pushNamed('/my_consultations');
                                    },
                                  );
                                },
                              );
                            },
                          ),
                          const Divider(height: 1, color: AppColors.border),
                          _accountRow(
                            icon: Icons.credit_card_rounded,
                            title: 'Billing',
                            subtitle: hasCard
                                ? 'Card on file'
                                : 'Add a card for consultations',
                            onTap: () {
                              Navigator.of(context, rootNavigator: true)
                                  .pushNamed('/paymentSetup');
                            },
                          ),
                          const Divider(height: 1, color: AppColors.border),
                          _accountRow(
                            icon: Icons.workspace_premium_outlined,
                            title: 'Premium',
                            subtitle: premiumSubtitle(),
                            onTap: () {
                              Navigator.of(context, rootNavigator: true)
                                  .pushNamed('/premium');
                            },
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Badges
                  if (badges.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _sectionTitle('Badges'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < badges.length && i < 3; i++)
                          _badgeChip(badges[i]),
                        if (badges.length > 3)
                          TextButton(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: AppColors.card,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(18)),
                                ),
                                builder: (_) => ListView(
                                  padding: const EdgeInsets.all(16),
                                  children: badges
                                      .map(
                                        (b) => ListTile(
                                          leading: const Icon(Icons.star_border,
                                              color: AppColors.text),
                                          title: Text(b,
                                              style: const TextStyle(
                                                  color: AppColors.text)),
                                        ),
                                      )
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
                  _sectionTitle('Featured Posts'),
                  SizedBox(
                    height: 210,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _postsStream,
                      builder: (ctx, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snap.hasError) {
                          return Center(
                            child: Text('Error: ${snap.error}',
                                style: const TextStyle(color: Colors.red)),
                          );
                        }

                        final all = (snap.data?.docs ?? []).toList();
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
                            child: Text('No featured posts yet.',
                                style: TextStyle(color: AppColors.muted)),
                          );
                        }

                        return PageView.builder(
                          controller: _pageController,
                          itemCount: featured.length,
                          padEnds: false,
                          physics: const BouncingScrollPhysics(),
                          itemBuilder: (c, i) {
                            final doc = featured[i];
                            final data = doc.data() as Map<String, dynamic>;
                            final date =
                                parseFirestoreTimestamp(data['timestamp']);
                            final (_, badgeText, body) = _classifyPost(data);

                            return Padding(
                              padding: EdgeInsets.only(
                                left: i == 0 ? 0 : 10,
                                right: i == featured.length - 1 ? 0 : 10,
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.of(context).push(
                                    CupertinoPageRoute(
                                        builder: (_) =>
                                            PostDetailScreen(postId: doc.id)),
                                  );
                                },
                                child: _softCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _postTypeBadge(badgeText),
                                      const SizedBox(height: 8),
                                      Expanded(
                                        child: RichText(
                                          text: _mdSpan(body),
                                          maxLines: 4,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (date != null)
                                        Text(
                                          DateFormat.yMMMd().format(date),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.muted),
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

                  // Filters
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, i) {
                        final label = _filters.keys.elementAt(i);
                        final selected = (label == _selectedFilterLabel);
                        return ChoiceChip(
                          key: ValueKey(label),
                          label: Text(
                            label,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? AppColors.text
                                  : AppColors.text.withOpacity(0.85),
                            ),
                          ),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _selectedFilterLabel = label),
                          selectedColor: AppColors.button,
                          backgroundColor: AppColors.card,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),
                  _sectionTitle('Recent Activity'),

                  StreamBuilder<QuerySnapshot>(
                    stream: _postsStream,
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return Center(
                          child: Text('Error: ${snap.error}',
                              style: const TextStyle(color: Colors.red)),
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

                      final selectedSlug = _filters[_selectedFilterLabel];

                      final items = docs.map((doc) {
                        final map = doc.data() as Map<String, dynamic>;
                        final tuple = _classifyPost(map);
                        return (
                          doc,
                          tuple.$1,
                          tuple.$2,
                          tuple.$3,
                          parseFirestoreTimestamp(map['timestamp'])
                        );
                      }).toList();

                      final filtered = selectedSlug == null
                          ? items
                          : items.where((e) => e.$2 == selectedSlug).toList();

                      if (filtered.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text('No activity yet.',
                                style: TextStyle(color: AppColors.muted)),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (c, i) {
                          final row = filtered[i];
                          final doc = row.$1;
                          final badgeText = row.$3;
                          final body = row.$4;
                          final dt = row.$5;

                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.of(context).push(
                                CupertinoPageRoute(
                                    builder: (_) =>
                                        PostDetailScreen(postId: doc.id)),
                              );
                            },
                            child: _softCard(
                              padding:
                                  const EdgeInsets.fromLTRB(14, 12, 14, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _postTypeBadge(badgeText),
                                  const SizedBox(height: 8),
                                  RichText(
                                    text: _mdSpan(body),
                                    maxLines: 8,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (dt != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      DateFormat.yMMMd().format(dt),
                                      style: const TextStyle(
                                          fontSize: 12, color: AppColors.muted),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
  }
}

// ---------- Compact stats strip ----------
class _StatsStrip extends StatelessWidget {
  final String streakText;
  final String xpText;
  final String helpfulText;
  const _StatsStrip({
    required this.streakText,
    required this.xpText,
    required this.helpfulText,
  });

  @override
  Widget build(BuildContext context) {
    Widget cell(IconData icon, String label, String value) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: AppColors.text),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: AppColors.muted)),
          ]),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      );
    }

    Widget divider() => Container(
          width: 1,
          height: 30,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          color: AppColors.border,
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
            child: Center(
                child: cell(Icons.local_fire_department_rounded, 'Streak',
                    streakText))),
        divider(),
        Expanded(
            child:
                Center(child: cell(Icons.emoji_events_outlined, 'XP', xpText))),
        divider(),
        Expanded(
            child: Center(
                child:
                    cell(Icons.thumb_up_alt_outlined, 'Helpful', helpfulText))),
      ],
    );
  }
}

// ---------- Collapsible bio ----------
class _ExpandableBio extends StatelessWidget {
  final String text;
  final bool expanded;
  final VoidCallback onToggle;
  const _ExpandableBio({
    required this.text,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final maxLines = expanded ? null : 2;
    final overflow = expanded ? TextOverflow.visible : TextOverflow.ellipsis;
    final showToggle = text.trim().length > 80;

    return Column(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          maxLines: maxLines,
          overflow: overflow,
          style: const TextStyle(color: AppColors.muted),
        ),
        if (showToggle) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onToggle,
            child: Text(
              expanded ? 'Show less' : 'More',
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FilledActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _FilledActionButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _OutlinedActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _OutlinedActionButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: AppColors.button,
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppColors.text),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
