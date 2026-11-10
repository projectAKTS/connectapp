// lib/screens/profile/profile_screen.dart
import 'package:connect_app/l10n/value_labels.dart';
import 'package:connect_app/l10n/l10n.dart';
import 'package:connect_app/l10n/formatters.dart';
import 'package:connect_app/screens/settings/settings_screen.dart';
import 'package:connect_app/utils/profile_text.dart';
import 'package:connect_app/services/safety_service.dart';
import 'package:connect_app/services/review_service.dart';
import 'package:connect_app/config/mvp_features.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:connect_app/utils/time_utils.dart';
import '../posts/post_detail_screen.dart';
import 'package:connect_app/widgets/initials_avatar.dart';
import 'package:connect_app/widgets/post_card.dart';
import 'edit_profile_screen.dart';
import 'package:connect_app/services/call_service.dart';
import 'package:connect_app/theme/tokens.dart';
import 'package:connect_app/widgets/full_screen_back_gesture.dart';
import 'package:connect_app/screens/profile/follow_list_screen.dart';
import 'package:connect_app/screens/messages/messages_screen.dart';
import 'package:connect_app/services/firestore_read_helper.dart';

class ProfileScreen extends StatefulWidget {
  final String userID;
  const ProfileScreen({Key? key, required this.userID}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ScrollController _scrollController = ScrollController();
  late final Stream<QuerySnapshot> _postsStream;

  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isCurrentUser = false;
  bool isFollowing = false;
  bool _followBusy = false;

  bool _bioExpanded = false;
  _ProfileTab _tab = _ProfileTab.posts;
  late final Stream<QuerySnapshot> _followersStream;

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

  /// Newest first; others do not see posts hidden by reports or the photo check.
  List<QueryDocumentSnapshot> _visiblePosts(List<QueryDocumentSnapshot> docs) {
    final out = docs
        .where((d) =>
            isCurrentUser ||
            !SafetyService.instance
                .hidesPost(d.id, d.data() as Map<String, dynamic>))
        .toList();
    DateTime at(QueryDocumentSnapshot d) =>
        parseFirestoreTimestamp(
            (d.data() as Map<String, dynamic>)['timestamp']) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    out.sort((a, b) => at(b).compareTo(at(a)));
    return out;
  }

  /// First photo or the video frame of a post, for the media grid.
  static String? _mediaThumb(Map<String, dynamic> m) {
    final photos = postImageUrls(m);
    if (photos.isNotEmpty) return photos.first;
    final frame = (m['videoThumbUrl'] ?? '').toString();
    return frame.isNotEmpty ? frame : null;
  }

  void _openFollowList(FollowListType type) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FollowListScreen(type: type, userId: widget.userID),
      ),
    );
  }

  void _openEditProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(userData: userData!),
      ),
    );
  }

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
    _followersStream = FirebaseFirestore.instance
        .collection('followers')
        .doc(widget.userID)
        .collection('userFollowers')
        .snapshots();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final snap = await FirestoreReadHelper.getDoc(
        FirebaseFirestore.instance.collection('users').doc(widget.userID),
      );
      if (!mounted) return;
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
        final followDoc = await FirestoreReadHelper.getDoc(
          FirebaseFirestore.instance
              .collection('followers')
              .doc(widget.userID)
              .collection('userFollowers')
              .doc(cur.uid),
        );
        following = followDoc.exists;
      }

      if (!mounted) return;
      setState(() {
        userData = Map<String, dynamic>.from(snap.data() as Map);
        isFollowing = following;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _snack(context.l10n.profileLoadFailed);
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
      _snack(context.l10n.profileLoginToFollow);
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
      _snack(context.l10n.profileFollowFailed);
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

  Future<void> _onSafetyAction(String action, String name) async {
    final safety = SafetyService.instance;
    switch (action) {
      case 'report':
        await safety.reportWithSheet(
          context,
          type: 'user',
          targetId: widget.userID,
          targetUid: widget.userID,
        );
      case 'block':
        await safety.blockWithConfirm(
          context,
          targetUid: widget.userID,
          name: name,
        );
      case 'unblock':
        await safety.setBlocked(widget.userID, false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.profileUnblocked(name))));
        }
    }
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
              if (MvpFeatures.paidSessions)
                item(
                    Icons.event_available_outlined, context.l10n.actionBookCall,
                    () {
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
              item(Icons.chat_bubble_outline, context.l10n.actionMessage, () {
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

              item(Icons.call, context.l10n.actionAudioCall,
                  () => _startCall(isVideo: false)),
              item(Icons.videocam, context.l10n.actionVideoCall,
                  () => _startCall(isVideo: true)),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ---------- Horizontal swipe-back handlers ----------
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
            title: Text(context.l10n.profileTitle),
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
            title: Text(context.l10n.profileTitle),
            leading:
                canPop ? BackButton(onPressed: () => nav.maybePop()) : null,
          ),
          body: Center(
            child: Text(context.l10n.profileNotFound,
                style: TextStyle(color: AppColors.muted)),
          ),
        ),
      ));
    }

    final boostedUntil = parseFirestoreTimestamp(userData!['boostedUntil']);
    final isBoosted =
        boostedUntil != null && boostedUntil.isAfter(DateTime.now());

    final fullName = _s(userData!['fullName'], 'Unknown User');
    final bio = placeholderBioToEmpty(_s(userData!['bio']));
    final badges = _stringList(userData!['badges']);
    final role = _s(userData!['role']);
    final isHelper =
        role == 'helper' || role == 'both' || userData!['isHelper'] == true;
    final city = _s(userData!['city']).trim();
    final roleAndCity = [
      if (isHelper) context.l10n.profileRoleHelper,
      if (city.isNotEmpty) city,
    ].join(' · ');
    final expertise = _stringList(userData!['expertiseTags']);
    final languages = _stringList(userData!['languages']);
    final ratingCount = _i(userData!['ratingCount']);
    final rating = (userData!['rating'] is num)
        ? (userData!['rating'] as num).toDouble()
        : 0.0;
    // Reviews come from booked sessions, so the tab is for helpers (or
    // anyone who already has some).
    final tabs = [
      _ProfileTab.posts,
      if (isHelper || ratingCount > 0) _ProfileTab.reviews,
      _ProfileTab.media,
    ];
    final tab = tabs.contains(_tab) ? _tab : _ProfileTab.posts;
    final showMedia = tab == _ProfileTab.media;

    // For Account section status (safe defaults)
    final premiumStatus = _s(userData!['premiumStatus']);
    final premiumExpiresAt =
        parseFirestoreTimestamp(userData!['premiumExpiresAt']);
    final hasCard = _s(userData!['defaultPaymentMethodId']).isNotEmpty;

    String premiumSubtitle() {
      if (premiumStatus.isEmpty) return context.l10n.profilePremiumNotActive;
      final exp = premiumExpiresAt != null
          ? AppFormat.date(context, premiumExpiresAt)
          : null;
      return exp == null
          ? premiumStatus
          : context.l10n.profilePremiumExpires(premiumStatus, exp);
    }

    return wrap(Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          leading: canPop ? BackButton(onPressed: () => nav.maybePop()) : null,
          title: Text(context.l10n.profileTitle),
          actions: [
            if (isCurrentUser) ...[
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: context.l10n.profileSettings,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
              ),
            ],
            if (!isCurrentUser)
              ValueListenableBuilder<Set<String>>(
                valueListenable: SafetyService.instance.blocked,
                builder: (context, blocked, _) {
                  final isBlocked = blocked.contains(widget.userID);
                  return PopupMenuButton<String>(
                    tooltip: context.l10n.profileMore,
                    onSelected: (action) => _onSafetyAction(action, fullName),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'report',
                        child: Text(context.l10n.profileReportUser),
                      ),
                      PopupMenuItem(
                        value: isBlocked ? 'unblock' : 'block',
                        child: Text(isBlocked
                            ? context.l10n.profileUnblock
                            : context.l10n.blockAction),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
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
                  // Header: photo, name, role and city
                  Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          InitialsAvatar(
                            url: _s(userData!['profilePicture']),
                            name: fullName,
                            radius: 40,
                          ),
                          if (isBoosted)
                            const Positioned(
                              right: -2,
                              top: -2,
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.orange,
                                child: Icon(Icons.star,
                                    color: Colors.white, size: 15),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                            if (roleAndCity.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                roleAndCity,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Counts
                  StreamBuilder<QuerySnapshot>(
                    stream: _postsStream,
                    builder: (context, snap) {
                      final posts = _visiblePosts(snap.data?.docs ?? []);
                      // Helpful marks are the post likes; nothing keeps the
                      // profile's own counter in sync.
                      final helpful = posts.fold<int>(
                          0,
                          (total, d) =>
                              total +
                              _i((d.data() as Map<String, dynamic>)['likes']));
                      return StreamBuilder<QuerySnapshot>(
                        stream: _followersStream,
                        builder: (context, followersSnap) => _HeaderStats(
                          cells: [
                            (
                              '${posts.length}',
                              context.l10n.profilePosts,
                              null,
                            ),
                            (
                              '${followersSnap.data?.docs.length ?? 0}',
                              context.l10n.profileFollowers,
                              () => _openFollowList(FollowListType.followers),
                            ),
                            (
                              '${_stringList(userData!['following']).length}',
                              context.l10n.profileFollowingList,
                              () => _openFollowList(FollowListType.following),
                            ),
                            ('$helpful', context.l10n.profileStatHelpful, null),
                            if (ratingCount > 0)
                              (
                                '★ ${rating.toStringAsFixed(1)}',
                                context.l10n.profileStatRating,
                                null,
                              ),
                          ],
                        ),
                      );
                    },
                  ),

                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _ExpandableBio(
                      text: bio,
                      expanded: _bioExpanded,
                      onToggle: () =>
                          setState(() => _bioExpanded = !_bioExpanded),
                    ),
                  ],

                  if (expertise.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      context.l10n.profileCanHelpWith,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in expertise)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              ValueLabels.topic(context.l10n, t),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (languages.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.translate_rounded,
                            size: 16, color: AppColors.muted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            context.l10n.profileSpeaks(languages
                                .map((c) =>
                                    ValueLabels.language(context.l10n, c))
                                .join(', ')),
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),
                  if (isCurrentUser)
                    _OutlinedActionButton(
                      icon: Icons.edit_outlined,
                      label: context.l10n.profileEditProfile,
                      onTap: _openEditProfile,
                    )
                  else
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
                                      label: context.l10n.profileFollowing,
                                      onTap: _toggleFollow,
                                    )
                                  : _FilledActionButton(
                                      key: const ValueKey('follow-pill'),
                                      icon: Icons.person_add_alt_1,
                                      label: context.l10n.profileFollow,
                                      onTap: _toggleFollow,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _OutlinedActionButton(
                            icon: Icons.flash_on_outlined,
                            label: context.l10n.actionConnect,
                            onTap: _openConnectSheet,
                          ),
                        ),
                      ],
                    ),

                  // ✅ Account hub (ONLY for current user)
                  if (isCurrentUser) ...[
                    const SizedBox(height: 16),
                    _softCard(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      child: Column(
                        children: [
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
                              final lastSeen =
                                  seenTimestamp(d, 'lastMessagesSeenAt');
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
                                        title: context.l10n.profileMessages,
                                        subtitle: conversationCount > 0
                                            ? context.l10n
                                                .profileConversationsCount(
                                                    conversationCount)
                                            : context
                                                .l10n.profileOpenConversations,
                                        badgeCount: unread,
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
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
                                lastSeen =
                                    seenTimestamp(d, 'lastConsultationsSeenAt');
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
                                    title: context.l10n.profileMyConsultations,
                                    subtitle: context
                                        .l10n.profileConsultationsSubtitle,
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
                          if (MvpFeatures.paidSessions) ...[
                            const Divider(height: 1, color: AppColors.border),
                            _accountRow(
                              icon: Icons.credit_card_rounded,
                              title: context.l10n.profileBilling,
                              subtitle: hasCard
                                  ? context.l10n.profileCardOnFile
                                  : context.l10n.profileAddCard,
                              onTap: () {
                                Navigator.of(context, rootNavigator: true)
                                    .pushNamed('/paymentSetup');
                              },
                            ),
                          ],
                          if (MvpFeatures.premium) ...[
                            const Divider(height: 1, color: AppColors.border),
                            _accountRow(
                              icon: Icons.workspace_premium_outlined,
                              title: context.l10n.profilePremium,
                              subtitle: premiumSubtitle(),
                              onTap: () {
                                Navigator.of(context, rootNavigator: true)
                                    .pushNamed('/premium');
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // Badges
                  if (badges.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _sectionTitle(context.l10n.profileBadges),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < badges.length && i < 3; i++)
                          _badgeChip(
                              ValueLabels.badge(context.l10n, badges[i])),
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
                            child: Text(context.l10n
                                .profileMoreBadges(badges.length - 3)),
                          ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),
                  _PostsTabs(
                    tabs: tabs,
                    selected: tab,
                    onChanged: (v) => setState(() => _tab = v),
                  ),
                  const SizedBox(height: 12),
                  if (tab == _ProfileTab.reviews)
                    _ReviewsTab(
                      helperUid: widget.userID,
                      rating: rating,
                      ratingCount: ratingCount,
                    )
                  else
                    StreamBuilder<QuerySnapshot>(
                      stream: _postsStream,
                      builder: (ctx, snap) {
                        if (snap.hasError) {
                          return Center(
                            child: Text(context.l10n.profileLoadError,
                                style: const TextStyle(color: Colors.red)),
                          );
                        }
                        if (!snap.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final all = _visiblePosts(snap.data!.docs);
                        final docs = showMedia
                            ? all
                                .where((d) =>
                                    _mediaThumb(
                                        d.data() as Map<String, dynamic>) !=
                                    null)
                                .toList()
                            : all;
                        if (docs.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Text(
                                  showMedia
                                      ? context.l10n.profileNoMedia
                                      : context.l10n.profileNoActivity,
                                  style:
                                      const TextStyle(color: AppColors.muted)),
                            ),
                          );
                        }
                        void open(String id) => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PostDetailScreen(postId: id),
                              ),
                            );
                        if (showMedia) {
                          return GridView.count(
                            crossAxisCount: 3,
                            mainAxisSpacing: 3,
                            crossAxisSpacing: 3,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              for (final doc in docs)
                                _MediaTile(
                                  data: doc.data() as Map<String, dynamic>,
                                  thumb: _mediaThumb(
                                      doc.data() as Map<String, dynamic>)!,
                                  onTap: () => open(doc.id),
                                ),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            for (final doc in docs)
                              PostCard(
                                key: ValueKey(doc.id),
                                postId: doc.id,
                                data: doc.data() as Map<String, dynamic>,
                                onOpenDetail: () => open(doc.id),
                              ),
                          ],
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
/// Posts, followers and the like as a row of numbers under the name.
class _HeaderStats extends StatelessWidget {
  final List<(String, String, VoidCallback?)> cells;
  const _HeaderStats({required this.cells});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (value, label, onTap) in cells)
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// "Posts | Photos & videos" switch above the author's posts.
enum _ProfileTab { posts, reviews, media }

/// Posts, reviews and media switch above the author's content.
class _PostsTabs extends StatelessWidget {
  final List<_ProfileTab> tabs;
  final _ProfileTab selected;
  final ValueChanged<_ProfileTab> onChanged;
  const _PostsTabs(
      {required this.tabs, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget tab(_ProfileTab value) {
      final (label, icon) = switch (value) {
        _ProfileTab.posts => (
            context.l10n.profilePosts,
            Icons.view_agenda_outlined
          ),
        _ProfileTab.reviews => (
            context.l10n.profileReviews,
            Icons.star_outline_rounded
          ),
        _ProfileTab.media => (
            context.l10n.profileTabMedia,
            Icons.grid_on_rounded
          ),
      };
      final on = value == selected;
      return Expanded(
        child: InkWell(
          onTap: () => onChanged(value),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: on ? AppColors.text : AppColors.border,
                  width: on ? 2 : 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 18, color: on ? AppColors.text : AppColors.muted),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: on ? AppColors.text : AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(children: [for (final t in tabs) tab(t)]);
  }
}

/// Star average and the written reviews from booked sessions.
class _ReviewsTab extends StatelessWidget {
  final String helperUid;
  final double rating;
  final int ratingCount;
  const _ReviewsTab(
      {required this.helperUid,
      required this.rating,
      required this.ratingCount});

  @override
  Widget build(BuildContext context) {
    if (ratingCount == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(context.l10n.profileNoReviews,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFFF2B01E), size: 26),
            const SizedBox(width: 6),
            Text(
              rating.toStringAsFixed(1),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
            Text(
              context.l10n.profileReviewsCount(ratingCount),
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ReviewsList(helperUid: helperUid),
      ],
    );
  }
}

/// One square in the photos and videos grid.
class _MediaTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String thumb;
  final VoidCallback onTap;
  const _MediaTile(
      {required this.data, required this.thumb, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isVideo = (data['videoUrl'] ?? '').toString().isNotEmpty;
    final many = postImageUrls(data).length > 1;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              thumb,
              fit: BoxFit.cover,
              loadingBuilder: (c, w, p) =>
                  p == null ? w : const ColoredBox(color: AppColors.button),
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: AppColors.button),
            ),
            if (isVideo || many)
              Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  isVideo
                      ? Icons.play_circle_fill_rounded
                      : Icons.collections_rounded,
                  color: Colors.white,
                  size: 20,
                  shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------- Reviews ----------
/// Written reviews from booked sessions, newest first. Reviewers stay
/// anonymous; stars-only reviews count in the average but are not listed.
class _ReviewsList extends StatelessWidget {
  final String helperUid;
  const _ReviewsList({required this.helperUid});

  static const int _shown = 20;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ReviewService.instance.reviewsOf(helperUid),
      builder: (context, snap) {
        final written = (snap.data ?? const [])
            .where((r) => '${r['text'] ?? ''}'.trim().isNotEmpty)
            .take(_shown)
            .toList();
        if (written.isEmpty) {
          return Text(
            context.l10n.profileNoWrittenReviews,
            style: TextStyle(color: AppColors.muted),
          );
        }
        return Column(
          children: [
            for (final r in written) ...[
              _ReviewTile(review: r),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final stars =
        (review['stars'] is num) ? (review['stars'] as num).toInt() : 0;
    final createdAt = parseFirestoreTimestamp(review['createdAt']);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border:
            const Border.fromBorderSide(BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Icon(
                  i <= stars ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 16,
                  color: i <= stars ? AppColors.primary : AppColors.muted,
                ),
              const Spacer(),
              Text(
                createdAt == null
                    ? context.l10n.profileBookedSession
                    : context.l10n.profileBookedSessionOn(
                        AppFormat.date(context, createdAt)),
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${review['text']}'.trim()),
        ],
      ),
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
    final maxLines = expanded ? null : 3;
    final overflow = expanded ? TextOverflow.visible : TextOverflow.ellipsis;
    final showToggle = text.trim().length > 120;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: maxLines,
          overflow: overflow,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 15,
            height: 1.35,
          ),
        ),
        if (showToggle) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onToggle,
            child: Text(
              expanded
                  ? context.l10n.commonShowLess
                  : context.l10n.profileBioMore,
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
