// lib/screens/home/home_content_screen.dart
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

import 'package:connect_app/screens/posts/post_video_player.dart';
import 'package:connect_app/screens/posts/post_image_viewer.dart';

import 'package:connect_app/widgets/main_scaffold.dart';

// ===== Utility functions =====
String _timeAgoShort(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inSeconds < 60) return '${diff.inSeconds}s';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo';
  return '${(diff.inDays / 365).floor()}y';
}

String _shortFromTs(dynamic ts) {
  final dt = parseFirestoreTimestamp(ts);
  if (dt == null) return 'now';
  return _timeAgoShort(dt);
}

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

  @override
  void initState() {
    super.initState();
    widget.controller.attach(this);
  }

  @override
  void dispose() {
    widget.controller.detach(this);
    _scroll.dispose();
    super.dispose();
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
              item(Icons.person_outline, 'View profile', () {
                tabNav.push(
                  CupertinoPageRoute(
                    builder: (_) => ProfileScreen(userID: otherUserId),
                  ),
                );

                // Or use the shared route style:
                // tabNav.pushNamed('/profile/$otherUserId');
              }),

              // ✅ NOW ALSO tab pushNamed (future-proof, consistent, keeps scroll)
              item(Icons.event_available_outlined, 'Book a call', () {
                tabNav.pushNamed(
                  '/consultation',
                  arguments: {
                    'targetUserId': otherUserId,
                    'targetUserName': otherUserName,
                    'ratePerMinute': 0,
                  },
                );
              }),

              item(Icons.chat_bubble_outline, 'Message', () {
                tabNav.pushNamed(
                  '/chat',
                  arguments: {
                    'otherUserId': otherUserId,
                    'otherUserName': otherUserName,
                  },
                );
              }),

              item(Icons.call, 'Audio call', () {
                _startCall(
                  toUid: otherUserId,
                  toName: otherUserName,
                  isVideo: false,
                );
              }),

              item(Icons.videocam, 'Video call', () {
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

  String _extractUserId(Map<String, dynamic> m) {
    for (final k in ['userId', 'userID', 'uid', 'authorId']) {
      final v = m[k];
      if (v is String && v.isNotEmpty) return v;
    }
    final ref = m['userRef'];
    try {
      final path = (ref?.path as String?);
      if (path != null && path.isNotEmpty) {
        final id = path.split('/').last;
        if (id.isNotEmpty) return id;
      }
    } catch (_) {}
    return '';
  }

  List<String> _extractImageUrls(Map<String, dynamic> raw) {
    final v = raw['imageUrls'];
    if (v is List) {
      return v
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final single = (raw['imageUrl'] ?? '').toString().trim();
    if (single.isNotEmpty) return [single];
    return [];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final user = FirebaseAuth.instance.currentUser;
    final currentUid = user?.uid ?? '';
    final fallbackName = (user?.displayName ?? '').trim();
    String firstFrom(String name) {
      final n = name.trim();
      if (n.isEmpty) return 'there';
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
                          CupertinoPageRoute(
                              builder: (_) => const FindHelperScreen()),
                        ),
                      )
                    : StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUid)
                            .snapshots(),
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
                              CupertinoPageRoute(
                                  builder: (_) => const FindHelperScreen()),
                            ),
                          );
                        },
                      ),
              ),
              const SliverToBoxAdapter(child: _SectionTitle('Recent posts')),
              SliverToBoxAdapter(
                child: StreamBuilder<QuerySnapshot>(
                  key: ValueKey('home_posts_$_postsReloadTick'),
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .orderBy('timestamp', descending: true)
                      .limit(_serverPostsLimit)
                      .snapshots(),
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
                              'Could not load posts right now.',
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
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }
                    final docs = snap.data?.docs ?? const [];
                    if (docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No posts yet! Create one to get started.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      );
                    }

                    final posts = docs;

                    final hasUploadingOwn = posts.any((doc) {
                      final raw = doc.data() as Map<String, dynamic>? ?? {};
                      final authorId = _extractUserId(raw);
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
                      final authorId = _extractUserId(raw);
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
                      return true;
                    }).toList();

                    final shownPosts = visiblePosts
                        .take(_displayPostsLimit)
                        .toList(growable: false);

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
                            final raw =
                                shownPosts[i].data() as Map<String, dynamic>? ??
                                    {};
                            final authorName =
                                (raw['userName'] ?? 'User') as String;
                            final authorId = _extractUserId(raw);
                            final avatar = (raw['userAvatar'] ?? '') as String;
                            final body = (raw['content'] ?? '').toString();

                            final right = _shortFromTs(raw['timestamp']);
                            final subtitle = '$right ago';

                            final imageUrls = _extractImageUrls(raw);

                            final videoUrl = (raw['videoUrl'] ?? '').toString();
                            final videoThumbUrl =
                                (raw['videoThumbUrl'] ?? '').toString();
                            final mediaStatus =
                                (raw['mediaUploadStatus'] ?? '').toString();
                            final mediaCount = (raw['mediaCount'] is num)
                                ? (raw['mediaCount'] as num).toInt()
                                : 0;
                            final mediaStartedAt = raw['mediaUploadStartedAt'];
                            final DateTime? uploadStartedAt = mediaStartedAt
                                    is Timestamp
                                ? mediaStartedAt.toDate()
                                : (raw['timestamp'] is Timestamp
                                    ? (raw['timestamp'] as Timestamp).toDate()
                                    : null);

                            final type = (raw['type'] ??
                                    raw['postType'] ??
                                    raw['templateType'] ??
                                    raw['template'] ??
                                    'Quick')
                                .toString();

                            final aspect = (() {
                              final v = raw['mediaAspectRatio'];
                              if (v is num && v > 0) return v.toDouble();
                              return (imageUrls.isNotEmpty ||
                                      videoUrl.isNotEmpty)
                                  ? (16 / 9)
                                  : 1.0;
                            })();

                            final isOwnPost = (authorId == currentUid);

                            return _PostCell(
                              postId: shownPosts[i].id,
                              postType: type,
                              authorName: authorName,
                              authorAvatarUrl: avatar,
                              subtitle: subtitle,
                              rightTime: right,
                              body: body,
                              imageUrls: imageUrls,
                              videoUrl: videoUrl,
                              videoThumbUrl: videoThumbUrl,
                              mediaAspect: aspect,
                              mediaStatus: mediaStatus,
                              mediaCount: mediaCount,
                              mediaUploadStartedAt: uploadStartedAt,
                              isOwnPost: isOwnPost,
                              onOpenProfile: authorId.isEmpty
                                  ? null
                                  : () {
                                      Navigator.of(context).push(
                                        CupertinoPageRoute(
                                          builder: (_) =>
                                              ProfileScreen(userID: authorId),
                                        ),
                                      );
                                      // or: Navigator.of(context).pushNamed('/profile/$authorId');
                                    },
                              onConnect: isOwnPost
                                  ? null
                                  : () {
                                      HapticFeedback.lightImpact();
                                      _openConnectSheet(
                                        otherUserId: authorId,
                                        otherUserName: authorName,
                                      );
                                    },
                              onOpenVideo: videoUrl.isEmpty
                                  ? null
                                  : () {
                                      Navigator.of(context).push(
                                        PageRouteBuilder(
                                          opaque: false,
                                          pageBuilder: (_, __, ___) =>
                                              PostVideoPlayer(url: videoUrl),
                                        ),
                                      );
                                    },
                              showConnect: !isOwnPost,
                            );
                          },
                        ),
                        if (shownPosts.length < visiblePosts.length ||
                            posts.length >= _serverPostsLimit)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                            child: OutlinedButton(
                              onPressed: _loadMorePosts,
                              child: const Text('Load more'),
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

// ===== Top bar =====
class _HomeTopBar extends StatelessWidget {
  final String currentUid;
  const _HomeTopBar({Key? key, required this.currentUid}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.displaySmall;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          Text('Home', style: titleStyle),
          const Spacer(),
          StreamBuilder<DocumentSnapshot>(
            stream: currentUid.isEmpty
                ? null
                : FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUid)
                    .snapshots(),
            builder: (context, userSnap) {
              final data = userSnap.data?.data() as Map<String, dynamic>? ??
                  const <String, dynamic>{};
              final lastSeen =
                  parseFirestoreTimestamp(data['lastMessagesSeenAt']);
              final userUnreadCounter =
                  _asUnreadCount(data['unreadMessagesCount']);

              return StreamBuilder<QuerySnapshot>(
                stream: currentUid.isEmpty
                    ? null
                    : FirebaseFirestore.instance
                        .collection('chats')
                        .where('participants', arrayContains: currentUid)
                        .snapshots(),
                builder: (context, chatSnapParticipants) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: currentUid.isEmpty
                        ? null
                        : FirebaseFirestore.instance
                            .collection('chats')
                            .where('users', arrayContains: currentUid)
                            .snapshots(),
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
                              tooltip: 'Messages',
                              onPressed: () {
                                Navigator.of(context).push(
                                  CupertinoPageRoute(
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
class _WelcomeCard extends StatelessWidget {
  final String name;
  final VoidCallback onFindHelper;

  const _WelcomeCard({
    required this.name,
    required this.onFindHelper,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

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
            Text('Welcome, $name',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            _TaupePill(
              icon: Icons.manage_search_rounded,
              label: 'Find a helper',
              onTap: onFindHelper,
            ),
            const SizedBox(height: 12),
            if (uid != null)
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .snapshots(),
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
                    stream: FirebaseFirestore.instance
                        .collection('connections')
                        .where('users', arrayContains: uid)
                        .snapshots(),
                    builder: (context, usersSnap) {
                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('connections')
                            .where('userId', isEqualTo: uid)
                            .snapshots(),
                        builder: (context, userIdSnap) {
                          return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('connections')
                                .where('connectedUserId', isEqualTo: uid)
                                .snapshots(),
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
                                    label: 'My connections',
                                    onTap: () {
                                      Navigator.of(context).push(
                                        CupertinoPageRoute(
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
        children: const [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.muted),
          ),
          SizedBox(width: 8),
          Text(
            'Posting in background…',
            style:
                TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ===== Post cell + media widgets (unchanged) =====

class _PostCell extends StatefulWidget {
  final String postId;
  final String postType;
  final String authorName;
  final String authorAvatarUrl;
  final String subtitle;
  final String rightTime;
  final String body;

  final List<String> imageUrls;
  final String videoUrl;
  final String videoThumbUrl;
  final double mediaAspect;
  final String mediaStatus;
  final int mediaCount;
  final DateTime? mediaUploadStartedAt;
  final bool isOwnPost;

  final VoidCallback? onOpenProfile;
  final VoidCallback? onConnect;
  final VoidCallback? onOpenVideo;
  final bool showConnect;

  const _PostCell({
    required this.postId,
    required this.postType,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.subtitle,
    required this.rightTime,
    required this.body,
    required this.imageUrls,
    required this.videoUrl,
    required this.videoThumbUrl,
    required this.mediaAspect,
    required this.mediaStatus,
    required this.mediaCount,
    required this.mediaUploadStartedAt,
    required this.isOwnPost,
    required this.onOpenProfile,
    required this.onConnect,
    required this.onOpenVideo,
    required this.showConnect,
  });

  @override
  State<_PostCell> createState() => _PostCellState();
}

class _PostCellState extends State<_PostCell> {
  static const _collapsedLines = 7;
  bool _expanded = false;
  bool _helpfulBusy = false;

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .delete();
  }

  Future<void> _toggleHelpful(bool isHelpful) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty || _helpfulBusy) return;
    setState(() => _helpfulBusy = true);
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .set({
        'likes': FieldValue.increment(isHelpful ? -1 : 1),
        'likedBy': isHelpful
            ? FieldValue.arrayRemove([uid])
            : FieldValue.arrayUnion([uid]),
      }, SetOptions(merge: true));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _helpfulBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget? media() {
      if (widget.imageUrls.isNotEmpty) {
        return _MediaCarousel(
          urls: widget.imageUrls,
          aspect: widget.mediaAspect,
          onOpenIndex: (idx) {
            // ✅ tab push for image viewer
            Navigator.of(context).push(
              PageRouteBuilder(
                opaque: false,
                pageBuilder: (_, __, ___) =>
                    PostImageViewer(url: widget.imageUrls[idx]),
              ),
            );
          },
        );
      }
      if (widget.videoUrl.isNotEmpty) {
        return _InlineVideoPlayer(
          url: widget.videoUrl,
          thumbUrl: widget.videoThumbUrl,
          aspect: widget.mediaAspect,
          onTap: widget.onOpenVideo,
        );
      }
      return null;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 14),
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PostHeader(
            authorName: widget.authorName,
            subtitle: widget.subtitle,
            rightTime: widget.rightTime,
            avatarUrl: widget.authorAvatarUrl,
            onTap: widget.onOpenProfile,
            trailing: widget.isOwnPost
                ? IconButton(
                    onPressed: _confirmDelete,
                    icon: const Icon(Icons.more_horiz, color: AppColors.muted),
                    tooltip: 'Post options',
                  )
                : null,
          ),
          const SizedBox(height: 8),
          _PostTypeBadge(label: _typeToBadge(widget.postType)),
          if (widget.body.isNotEmpty) const SizedBox(height: 8),
          if (widget.body.isNotEmpty)
            _ExpandableStructuredText(
              content: widget.body,
              expanded: _expanded,
              maxLinesWhenCollapsed: _collapsedLines,
              onToggle: () => setState(() => _expanded = !_expanded),
            ),
          if (media() != null) const SizedBox(height: 8),
          if (media() != null) media()!,
          const SizedBox(height: 8),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .doc(widget.postId)
                .snapshots(),
            builder: (context, snap) {
              final data = snap.data?.data() ?? const <String, dynamic>{};
              final likes =
                  (data['likes'] is num) ? (data['likes'] as num).toInt() : 0;
              final likedBy = ((data['likedBy'] as List?) ?? const [])
                  .map((e) => '$e')
                  .toSet();
              final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
              final isHelpful = uid.isNotEmpty && likedBy.contains(uid);
              return Row(
                children: [
                  TextButton.icon(
                    onPressed:
                        _helpfulBusy ? null : () => _toggleHelpful(isHelpful),
                    icon: Icon(
                      isHelpful ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: isHelpful ? AppColors.primary : AppColors.muted,
                    ),
                    label: Text(
                      'Helpful',
                      style: TextStyle(
                        color: isHelpful ? AppColors.primary : AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (likes > 0)
                    Text(
                      '$likes',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              );
            },
          ),
          if (widget.showConnect) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: widget.onConnect,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                backgroundColor: AppColors.canvas,
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  side: const BorderSide(color: AppColors.primary, width: 1.2),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              child: const Text('Connect'),
            ),
          ],
        ],
      ),
    );
  }

  String _typeToBadge(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 'Quick Post';
    if (t.toLowerCase() == 'quick') return 'Quick Post';
    return t.endsWith('Post') ? t : '$t Post';
  }
}

class _PostHeader extends StatelessWidget {
  final String authorName;
  final String subtitle;
  final String rightTime;
  final String avatarUrl;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _PostHeader({
    required this.authorName,
    required this.subtitle,
    required this.rightTime,
    required this.avatarUrl,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        _Avatar(url: avatarUrl, radius: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                authorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
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
        const SizedBox(width: 8),
        Text(
          rightTime,
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.muted,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 4),
          trailing!,
        ],
      ],
    );

    return onTap == null
        ? row
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: row,
            ),
          );
  }
}

class _PostTypeBadge extends StatelessWidget {
  final String label;
  const _PostTypeBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withOpacity(0.12)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
          letterSpacing: 0.15,
        ),
      ),
    );
  }
}

// ===== Expandable Structured Text =====
class _ExpandableStructuredText extends StatelessWidget {
  final String content;
  final bool expanded;
  final int maxLinesWhenCollapsed;
  final VoidCallback onToggle;

  const _ExpandableStructuredText({
    required this.content,
    required this.expanded,
    required this.maxLinesWhenCollapsed,
    required this.onToggle,
  });

  bool _looksLikeQuestion(String s) {
    final t = s.trim();
    if (t.isEmpty) return false;
    if (t.endsWith('?')) return true;

    final lower = t.toLowerCase();
    return lower.startsWith('what ') ||
        lower.startsWith("what’s ") ||
        lower.startsWith('whats ') ||
        lower.startsWith('how ') ||
        lower.startsWith('list ') ||
        lower.startsWith('topic ') ||
        lower.startsWith('one key ');
  }

  TextSpan _buildSpan(String raw) {
    const base = TextStyle(
      fontSize: 15.5,
      height: 1.28,
      color: AppColors.text,
      fontWeight: FontWeight.w400,
    );
    const strong = TextStyle(
      fontSize: 15.5,
      height: 1.28,
      color: AppColors.text,
      fontWeight: FontWeight.w800,
    );

    final lines = raw.split('\n');
    final spans = <InlineSpan>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isQ = _looksLikeQuestion(line);
      spans.add(TextSpan(text: line, style: isQ ? strong : base));
      if (i != lines.length - 1) spans.add(const TextSpan(text: '\n'));
    }

    return TextSpan(children: spans, style: base);
  }

  @override
  Widget build(BuildContext context) {
    final span = _buildSpan(content);

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final tp = TextPainter(
          text: span,
          textDirection: TextDirection.ltr,
          maxLines: maxLinesWhenCollapsed,
        )..layout(maxWidth: constraints.maxWidth);

        final hasOverflow = tp.didExceedMaxLines;
        Widget rich() => RichText(text: span);

        if (!hasOverflow) return rich();

        if (expanded) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              rich(),
              const SizedBox(height: 4),
              _ShowMoreButton(expanded: true, onTap: onToggle),
            ],
          );
        }

        final collapsedHeight = tp.preferredLineHeight * maxLinesWhenCollapsed;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: collapsedHeight,
              child: ClipRect(
                child: ShaderMask(
                  shaderCallback: (Rect r) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Color(0xCCFFFFFF),
                        Color(0xFFFFFFFF),
                      ],
                      stops: [0.0, 0.78, 0.92, 1.0],
                    ).createShader(r);
                  },
                  blendMode: BlendMode.dstOut,
                  child: rich(),
                ),
              ),
            ),
            const SizedBox(height: 4),
            _ShowMoreButton(expanded: false, onTap: onToggle),
          ],
        );
      },
    );
  }
}

class _ShowMoreButton extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;

  const _ShowMoreButton({required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            expanded ? 'Show less' : 'Show more',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            expanded ? Icons.expand_less : Icons.expand_more,
            size: 16,
            color: AppColors.muted,
          ),
        ],
      ),
    );
  }
}

// ===== Media widgets =====
class _MediaCarousel extends StatefulWidget {
  final List<String> urls;
  final double aspect;
  final ValueChanged<int> onOpenIndex;

  const _MediaCarousel({
    required this.urls,
    required this.aspect,
    required this.onOpenIndex,
  });

  @override
  State<_MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<_MediaCarousel> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;

    if (urls.length == 1) {
      return _MediaImage(
        url: urls.first,
        aspect: widget.aspect,
        onTap: () => widget.onOpenIndex(0),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: widget.aspect,
            child: PageView.builder(
              itemCount: urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                return InkWell(
                  onTap: () => widget.onOpenIndex(i),
                  child: Image.network(
                    urls[i],
                    fit: BoxFit.cover,
                    loadingBuilder: (c, w, p) =>
                        p == null ? w : Container(color: AppColors.button),
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.button,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image,
                          color: AppColors.muted),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(urls.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 14 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(active ? 0.55 : 0.25),
                    borderRadius: BorderRadius.circular(99),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaImage extends StatelessWidget {
  final String url;
  final double aspect;
  final VoidCallback? onTap;

  const _MediaImage({
    required this.url,
    required this.aspect,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: aspect,
        child: InkWell(
          onTap: onTap,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (c, w, p) =>
                p == null ? w : Container(color: AppColors.button),
            errorBuilder: (_, __, ___) => Container(
              color: AppColors.button,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image, color: AppColors.muted),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineVideoPlayer extends StatelessWidget {
  final String url;
  final String thumbUrl;
  final double aspect;
  final VoidCallback? onTap;

  const _InlineVideoPlayer({
    required this.url,
    required this.thumbUrl,
    required this.aspect,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final aspect = this.aspect > 0 ? this.aspect : (16 / 9);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: (aspect.isFinite && aspect > 0) ? aspect : (16 / 9),
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumbUrl.isNotEmpty)
                Image.network(
                  thumbUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (c, w, p) =>
                      p == null ? w : Container(color: AppColors.button),
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.button,
                    alignment: Alignment.center,
                    child: const Icon(Icons.videocam_outlined,
                        color: AppColors.muted, size: 30),
                  ),
                )
              else
                Container(
                  color: AppColors.button,
                  alignment: Alignment.center,
                  child: const Icon(Icons.videocam_outlined,
                      color: AppColors.muted, size: 30),
                ),
              const Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 52,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== Avatar =====
class _Avatar extends StatelessWidget {
  final String url;
  final double radius;

  const _Avatar({required this.url, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    return url.isEmpty
        ? CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.avatarBg,
            child: const Icon(Icons.person_outline, color: AppColors.avatarFg),
          )
        : CircleAvatar(
            radius: radius,
            backgroundImage: NetworkImage(url),
          );
  }
}
