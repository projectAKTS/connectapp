// lib/screens/home/home_content_screen.dart
import 'package:connect_app/config/mvp_features.dart';
import 'package:connect_app/l10n/l10n.dart';
import 'package:connect_app/services/safety_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:connect_app/utils/time_utils.dart';
import 'package:connect_app/theme/tokens.dart';
import 'package:connect_app/screens/connections/connections_screen.dart';
import 'package:connect_app/screens/profile/profile_screen.dart';
import 'package:connect_app/screens/messages/messages_screen.dart';
import 'package:connect_app/screens/search/find_helper_screen.dart';
import 'package:connect_app/services/call_service.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';


import 'package:connect_app/widgets/main_scaffold.dart';
import 'package:connect_app/widgets/post_card.dart';
import 'package:connect_app/screens/posts/post_detail_screen.dart';

// ===== Utility functions =====

int _asUnreadCount(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim()) ?? 0;
  return 0;
}

// ===== Main screen =====
class HomeContentScreen extends StatefulWidget {
  final HomeTabController controller;

  const HomeContentScreen({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  HomeContentScreenState createState() => HomeContentScreenState();
}

class HomeContentScreenState extends State<HomeContentScreen>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scroll = ScrollController();
  int _postsReloadTick = 0;
  int _displayPostsLimit = 30;
  int _serverPostsLimit = 120;

  // Streams are cached so a rebuild (inherited data, parent updates) never
  // re-subscribes Firestore listeners; see [_HomeTopBarState].
  String? _welcomeUserStreamUid;
  Stream<DocumentSnapshot>? _welcomeUserStream;
  String? _postsStreamKey;
  Stream<QuerySnapshot>? _postsStream;

  Stream<DocumentSnapshot> _welcomeUserStreamFor(String uid) {
    if (_welcomeUserStreamUid != uid || _welcomeUserStream == null) {
      _welcomeUserStreamUid = uid;
      _welcomeUserStream = HelperlyTestRuntime.firestore
          .collection('users')
          .doc(uid)
          .snapshots();
    }
    return _welcomeUserStream!;
  }

  Stream<QuerySnapshot> _currentPostsStream() {
    final key = '$_postsReloadTick:$_serverPostsLimit';
    if (_postsStreamKey != key || _postsStream == null) {
      _postsStreamKey = key;
      _postsStream = HelperlyTestRuntime.firestore
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(_serverPostsLimit)
          .snapshots();
    }
    return _postsStream!;
  }

  @override
  void initState() {
    super.initState();
    widget.controller.attach(this);
    SafetyService.instance.watch();
    SafetyService.instance.blocked.addListener(_onBlockedChanged);
    SafetyService.instance.hiddenPosts.addListener(_onBlockedChanged);
  }

  @override
  void dispose() {
    SafetyService.instance.blocked.removeListener(_onBlockedChanged);
    SafetyService.instance.hiddenPosts.removeListener(_onBlockedChanged);
    widget.controller.detach(this);
    _scroll.dispose();
    super.dispose();
  }

  void _onBlockedChanged() {
    if (mounted) setState(() {});
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _scrollToTop({bool haptic = true}) async {
    if (haptic) HapticFeedback.mediumImpact();
    if (_scroll.hasClients) {
      await _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> scrollToTopFromTab() async {
    await _scrollToTop(haptic: true);
  }

  Future<void> _onRefresh() async {
    await _scrollToTop(haptic: true);
    if (mounted) {
      setState(() {
        _postsReloadTick++;
        _displayPostsLimit = 30;
        _serverPostsLimit = 120;
      });
    }
    await Future.delayed(const Duration(milliseconds: 600));
  }

  void _loadMorePosts() {
    if (!mounted) return;
    setState(() {
      _displayPostsLimit += 30;
      // Expand backend query only when local window is close to server cap.
      if (_displayPostsLimit >= _serverPostsLimit - 10) {
        _serverPostsLimit += 120;
      }
    });
  }

  Future<void> _startCall({
    required String toUid,
    required String toName,
    required bool isVideo,
  }) async {
    // Calls are "global fullscreen" -> root navigator is fine.
    final rootCtx = Navigator.of(context, rootNavigator: true).context;

    await CallService().startCall(
      rootCtx,
      toUid: toUid,
      toName: toName,
      isVideo: isVideo,
    );
  }

  void _openConnectSheet({
    required String otherUserId,
    required String otherUserName,
  }) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (otherUserId == currentUser?.uid) return;

    final tabNav = Navigator.of(context);

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

              // ✅ Keep as tab push (perfectly preserves position)
              item(Icons.person_outline, context.l10n.actionViewProfile, () {
                tabNav.push(
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(userID: otherUserId),
                  ),
                );

                // Or use the shared route style:
                // tabNav.pushNamed('/profile/$otherUserId');
              }),

              // ✅ NOW ALSO tab pushNamed (future-proof, consistent, keeps scroll)
              if (MvpFeatures.paidSessions)
                item(
                    Icons.event_available_outlined, context.l10n.actionBookCall,
                    () {
                  tabNav.pushNamed(
                    '/consultation',
                    arguments: {
                      'targetUserId': otherUserId,
                      'targetUserName': otherUserName,
                      'ratePerMinute': 0,
                    },
                  );
                }),

              item(Icons.chat_bubble_outline, context.l10n.actionMessage, () {
                tabNav.pushNamed(
                  '/chat',
                  arguments: {
                    'otherUserId': otherUserId,
                    'otherUserName': otherUserName,
                  },
                );
              }),

              item(Icons.call, context.l10n.actionAudioCall, () {
                _startCall(
                  toUid: otherUserId,
                  toName: otherUserName,
                  isVideo: false,
                );
              }),

              item(Icons.videocam, context.l10n.actionVideoCall, () {
                _startCall(
                  toUid: otherUserId,
                  toName: otherUserName,
                  isVideo: true,
                );
              }),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final currentUid = HelperlyTestRuntime.currentUid ?? '';
    final fallbackName = (HelperlyTestRuntime.currentDisplayName ?? '').trim();
    String firstFrom(String name) {
      final n = name.trim();
      if (n.isEmpty) return context.l10n.homeWelcomeThere;
      return n.split(' ').first;
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: RefreshIndicator.adaptive(
          onRefresh: _onRefresh,
          edgeOffset: 0,
          displacement: 56,
          child: CustomScrollView(
            key: const PageStorageKey('homeScroll'),
            controller: _scroll,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _HomeTopBar(currentUid: currentUid)),
              SliverToBoxAdapter(
                child: currentUid.isEmpty
                    ? _WelcomeCard(
                        name: firstFrom(fallbackName),
                        onFindHelper: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const FindHelperScreen()),
                        ),
                      )
                    : StreamBuilder<DocumentSnapshot>(
                        stream: _welcomeUserStreamFor(currentUid),
                        builder: (context, snap) {
                          final data =
                              snap.data?.data() as Map<String, dynamic>? ?? {};
                          final name = (data['displayName'] ??
                                  data['fullName'] ??
                                  fallbackName)
                              .toString();
                          return _WelcomeCard(
                            name: firstFrom(name),
                            onFindHelper: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const FindHelperScreen()),
                            ),
                          );
                        },
                      ),
              ),
              SliverToBoxAdapter(
                  child: _SectionTitle(context.l10n.homeRecentPosts)),
              SliverToBoxAdapter(
                child: StreamBuilder<QuerySnapshot>(
                  key: ValueKey('home_posts_$_postsReloadTick'),
                  stream: _currentPostsStream(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting &&
                        !snap.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snap.hasError) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.homeLoadFailed,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(color: Colors.red.shade700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${snap.error}',
                              style: const TextStyle(color: AppColors.muted),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: () {
                                setState(() => _postsReloadTick++);
                              },
                              child: Text(context.l10n.commonRetry),
                            ),
                          ],
                        ),
                      );
                    }
                    final docs = snap.data?.docs ?? const [];
                    if (docs.isEmpty) {
                      return Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          context.l10n.homeNoPosts,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      );
                    }

                    final posts = docs;

                    final hasUploadingOwn = posts.any((doc) {
                      final raw = doc.data() as Map<String, dynamic>? ?? {};
                      final authorId = postAuthorId(raw);
                      if (authorId != currentUid) return false;
                      if ((raw['mediaUploadStatus'] ?? '') != 'uploading')
                        return false;
                      final started = raw['mediaUploadStartedAt'];
                      final DateTime? startedAt = started is Timestamp
                          ? started.toDate()
                          : (raw['timestamp'] is Timestamp
                              ? (raw['timestamp'] as Timestamp).toDate()
                              : null);
                      if (startedAt == null) return true;
                      return DateTime.now().difference(startedAt) <=
                          const Duration(minutes: 4);
                    });

                    final visiblePosts = posts.where((doc) {
                      final raw = doc.data() as Map<String, dynamic>? ?? {};
                      final status =
                          (raw['mediaUploadStatus'] ?? '').toString();
                      final authorId = postAuthorId(raw);
                      final mediaCount = (raw['mediaCount'] is num)
                          ? (raw['mediaCount'] as num).toInt()
                          : 0;
                      final hasVideo = raw['hasVideo'] == true;
                      final hasMedia = mediaCount > 0 || hasVideo;
                      if (authorId == currentUid &&
                          status == 'uploading' &&
                          hasMedia) {
                        return false;
                      }
                      return !SafetyService.instance.isBlocked(authorId) &&
                          !SafetyService.instance.hidesPost(doc.id, raw);
                    }).toList();

                    final shownPosts = visiblePosts
                        .take(_displayPostsLimit)
                        .toList(growable: false);
                    // Everything filtered out (blocked, reported or hidden):
                    // same message as an empty feed, not a blank area.
                    if (shownPosts.isEmpty && !hasUploadingOwn) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          context.l10n.homeNoPosts,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        if (hasUploadingOwn)
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 6, 16, 8),
                            child: _UploadBanner(),
                          ),
                        ListView.separated(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                          itemCount: shownPosts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 0),
                          itemBuilder: (_, i) {
                            final doc = shownPosts[i];
                            final raw = doc.data() as Map<String, dynamic>? ??
                                <String, dynamic>{};
                            final authorId = postAuthorId(raw);
                            final authorName =
                                (raw['userName'] ?? 'User').toString();
                            return PostCard(
                              key: ValueKey(doc.id),
                              postId: doc.id,
                              data: raw,
                              onOpenDetail: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PostDetailScreen(postId: doc.id),
                                ),
                              ),
                              onConnect: authorId.isEmpty ||
                                      authorId == currentUid
                                  ? null
                                  : () {
                                      HapticFeedback.lightImpact();
                                      _openConnectSheet(
                                        otherUserId: authorId,
                                        otherUserName: authorName,
                                      );
                                    },
                            );
                          },
                        ),
                        if (shownPosts.length < visiblePosts.length ||
                            posts.length >= _serverPostsLimit)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                            child: OutlinedButton(
                              onPressed: _loadMorePosts,
                              child: Text(context.l10n.commonLoadMore),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

@visibleForTesting
Widget homeTopBarForTest({required String currentUid}) =>
    _HomeTopBar(currentUid: currentUid);

@visibleForTesting
Widget homeWelcomeCardForTest({required String name}) =>
    _WelcomeCard(name: name, onFindHelper: () {});

// ===== Top bar =====
class _HomeTopBar extends StatefulWidget {
  final String currentUid;
  const _HomeTopBar({Key? key, required this.currentUid}) : super(key: key);

  @override
  State<_HomeTopBar> createState() => _HomeTopBarState();
}

/// Home stays mounted under every call route, so its Firestore streams are
/// created once per user id. Creating `.snapshots()` inside `build()` turned
/// every `users/{uid}` write into new watch targets, and that watch-stream
/// churn preceded the iOS Firestore client wedging during consecutive calls.
class _HomeTopBarState extends State<_HomeTopBar> {
  Stream<DocumentSnapshot>? _userStream;
  Stream<QuerySnapshot>? _chatsByParticipantsStream;
  Stream<QuerySnapshot>? _chatsByUsersStream;

  @override
  void initState() {
    super.initState();
    _bindStreams();
  }

  @override
  void didUpdateWidget(covariant _HomeTopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUid != widget.currentUid) _bindStreams();
  }

  void _bindStreams() {
    final currentUid = widget.currentUid;
    if (currentUid.isEmpty) {
      _userStream = null;
      _chatsByParticipantsStream = null;
      _chatsByUsersStream = null;
      return;
    }
    final db = HelperlyTestRuntime.firestore;
    _userStream = db.collection('users').doc(currentUid).snapshots();
    _chatsByParticipantsStream = db
        .collection('chats')
        .where('participants', arrayContains: currentUid)
        .snapshots();
    _chatsByUsersStream = db
        .collection('chats')
        .where('users', arrayContains: currentUid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = widget.currentUid;
    final titleStyle = Theme.of(context).textTheme.displaySmall;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          Text(context.l10n.homeTitle, style: titleStyle),
          const Spacer(),
          StreamBuilder<DocumentSnapshot>(
            stream: _userStream,
            builder: (context, userSnap) {
              final data = userSnap.data?.data() as Map<String, dynamic>? ??
                  const <String, dynamic>{};
              final lastSeen = seenTimestamp(data, 'lastMessagesSeenAt');
              final userUnreadCounter =
                  _asUnreadCount(data['unreadMessagesCount']);

              return StreamBuilder<QuerySnapshot>(
                stream: _chatsByParticipantsStream,
                builder: (context, chatSnapParticipants) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: _chatsByUsersStream,
                    builder: (context, chatSnapUsers) {
                      final merged = <String, Map<String, dynamic>>{};
                      if (chatSnapParticipants.hasData) {
                        for (final doc in chatSnapParticipants.data!.docs) {
                          merged[doc.id] =
                              (doc.data() as Map<String, dynamic>? ??
                                  const <String, dynamic>{});
                        }
                      }
                      if (chatSnapUsers.hasData) {
                        for (final doc in chatSnapUsers.data!.docs) {
                          merged[doc.id] =
                              (doc.data() as Map<String, dynamic>? ??
                                  const <String, dynamic>{});
                        }
                      }

                      var unread = userUnreadCounter;
                      if (unread <= 0) {
                        for (final m in merged.values) {
                          final unreadBy = m['unreadBy'];
                          if (unreadBy is Map) {
                            final value = _asUnreadCount(unreadBy[currentUid]);
                            if (value > 0) {
                              unread += value;
                              continue;
                            }
                          }
                          final updated =
                              parseFirestoreTimestamp(m['updatedAt']) ??
                                  parseFirestoreTimestamp(m['lastMessageAt']);
                          final author =
                              (m['lastMessageAuthorId'] ?? '').toString();
                          if (updated != null &&
                              author != currentUid &&
                              (lastSeen == null || updated.isAfter(lastSeen))) {
                            unread += 1;
                          }
                        }
                      }

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.chip,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: AppColors.primary,
                              ),
                              tooltip: context.l10n.homeMessages,
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => MessagesScreen(
                                      userId: currentUid,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (unread > 0)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '+$unread',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// ===== Welcome Card =====
class _WelcomeCard extends StatefulWidget {
  final String name;
  final VoidCallback onFindHelper;

  const _WelcomeCard({
    required this.name,
    required this.onFindHelper,
  });

  @override
  State<_WelcomeCard> createState() => _WelcomeCardState();
}

/// Streams are created once per signed-in user id, never in `build()`; see
/// [_HomeTopBarState].
class _WelcomeCardState extends State<_WelcomeCard> {
  String? _boundUid;
  Stream<DocumentSnapshot>? _userStream;
  Stream<QuerySnapshot>? _connectionsByUsersStream;
  Stream<QuerySnapshot>? _connectionsByUserIdStream;
  Stream<QuerySnapshot>? _connectionsByConnectedUserIdStream;

  void _bindStreams(String uid) {
    if (_boundUid == uid) return;
    _boundUid = uid;
    final db = HelperlyTestRuntime.firestore;
    _userStream = db.collection('users').doc(uid).snapshots();
    _connectionsByUsersStream = db
        .collection('connections')
        .where('users', arrayContains: uid)
        .snapshots();
    _connectionsByUserIdStream = db
        .collection('connections')
        .where('userId', isEqualTo: uid)
        .snapshots();
    _connectionsByConnectedUserIdStream = db
        .collection('connections')
        .where('connectedUserId', isEqualTo: uid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.name;
    final onFindHelper = widget.onFindHelper;
    final uid = HelperlyTestRuntime.currentUid;
    if (uid != null) _bindStreams(uid);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: const [AppShadows.soft],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.border.withOpacity(0.45),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.homeWelcome(name),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            _TaupePill(
              icon: Icons.manage_search_rounded,
              label: context.l10n.findHelperTitle,
              onTap: onFindHelper,
            ),
            const SizedBox(height: 12),
            if (uid != null)
              StreamBuilder<DocumentSnapshot>(
                stream: _userStream,
                builder: (context, userSnap) {
                  int seenCount = 0;
                  if (userSnap.hasData) {
                    final d = userSnap.data!.data() as Map<String, dynamic>?;
                    final raw = d?['connectionsCountSeen'];
                    if (raw is num && raw >= 0) {
                      seenCount = raw.toInt();
                    }
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: _connectionsByUsersStream,
                    builder: (context, usersSnap) {
                      return StreamBuilder<QuerySnapshot>(
                        stream: _connectionsByUserIdStream,
                        builder: (context, userIdSnap) {
                          return StreamBuilder<QuerySnapshot>(
                            stream: _connectionsByConnectedUserIdStream,
                            builder: (context, connectedUserIdSnap) {
                              final merged = <String, Map<String, dynamic>>{};
                              if (usersSnap.hasData) {
                                for (final doc in usersSnap.data!.docs) {
                                  merged[doc.id] =
                                      (doc.data() as Map<String, dynamic>? ??
                                          const <String, dynamic>{});
                                }
                              }
                              if (userIdSnap.hasData) {
                                for (final doc in userIdSnap.data!.docs) {
                                  merged[doc.id] =
                                      (doc.data() as Map<String, dynamic>? ??
                                          const <String, dynamic>{});
                                }
                              }
                              if (connectedUserIdSnap.hasData) {
                                for (final doc
                                    in connectedUserIdSnap.data!.docs) {
                                  merged[doc.id] =
                                      (doc.data() as Map<String, dynamic>? ??
                                          const <String, dynamic>{});
                                }
                              }

                              final peerIds = <String>{};
                              for (final m in merged.values) {
                                final users =
                                    ((m['users'] as List?) ?? const [])
                                        .map((e) => e.toString())
                                        .where((e) => e.isNotEmpty)
                                        .toList();
                                if (users.isNotEmpty) {
                                  for (final id in users) {
                                    if (id != uid) peerIds.add(id);
                                  }
                                  continue;
                                }
                                final u1 = (m['userId'] ?? '').toString();
                                final u2 =
                                    (m['connectedUserId'] ?? '').toString();
                                if (u1 == uid && u2.isNotEmpty) {
                                  peerIds.add(u2);
                                } else if (u2 == uid && u1.isNotEmpty) {
                                  peerIds.add(u1);
                                }
                              }

                              final recentCount =
                                  (peerIds.length - seenCount).clamp(0, 9999);

                              return Stack(
                                children: [
                                  _TaupePill(
                                    icon: Icons.people_alt_outlined,
                                    label: context.l10n.homeMyConnections,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const ConnectionsScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  if (recentCount > 0)
                                    Positioned(
                                      right: 14,
                                      top: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '+$recentCount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _TaupePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TaupePill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.button,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(icon, color: AppColors.muted, size: 22),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _UploadBanner extends StatelessWidget {
  const _UploadBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.button,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.muted),
          ),
          SizedBox(width: 8),
          Text(
            context.l10n.homePostingInBackground,
            style:
                TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ===== Post cell + media widgets (unchanged) =====
