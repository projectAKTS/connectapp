// lib/screens/home/home_content_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:connect_app/utils/time_utils.dart';
import 'package:connect_app/theme/tokens.dart';
import 'package:connect_app/screens/connections/connections_screen.dart';
import 'package:connect_app/screens/profile/profile_screen.dart';
import 'package:connect_app/screens/messages/messages_screen.dart';

// Fullscreen viewers
import 'package:connect_app/screens/posts/post_video_player.dart';
import 'package:connect_app/screens/posts/post_image_viewer.dart';

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

// ===== Main screen =====
class HomeContentScreen extends StatefulWidget {
  const HomeContentScreen({Key? key}) : super(key: key);

  @override
  State<HomeContentScreen> createState() => _HomeContentScreenState();
}

class _HomeContentScreenState extends State<HomeContentScreen> {
  final ScrollController _scroll = ScrollController();

  void _openConnectSheet({
    required String otherUserId,
    required String otherUserName,
  }) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (otherUserId == currentUser?.uid) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        Widget _item(IconData icon, String label, VoidCallback onTap) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.avatarBg,
              child: Icon(icon, color: AppColors.avatarFg),
            ),
            title: Text(label, style: const TextStyle(color: AppColors.text)),
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
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 10),
              _item(Icons.phone_in_talk_rounded, 'Audio call', () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Audio call — coming soon')),
                );
              }),
              _item(Icons.videocam_rounded, 'Video call', () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Video call — coming soon')),
                );
              }),
              _item(Icons.chat_bubble_outline_rounded, 'Message', () {
                Navigator.of(context).pushNamed(
                  '/chat',
                  arguments: {'otherUserId': otherUserId},
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firstName = (user?.displayName ?? 'Maria').split(' ').first;
    final currentUid = user?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            const SliverToBoxAdapter(child: _HomeTopBar()),
            SliverToBoxAdapter(
              child: _WelcomeCard(
                name: firstName,
                onFindHelper: () =>
                    Navigator.of(context, rootNavigator: true).pushNamed('/search'),
              ),
            ),
            const SliverToBoxAdapter(child: _SectionTitle('Recent posts')),
            SliverToBoxAdapter(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (!snap.hasData || snap.data!.docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No posts yet! Create one to get started.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    );
                  }

                  final posts = snap.data!.docs;

                  return ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: posts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (_, i) {
                      final raw = posts[i].data() as Map<String, dynamic>? ?? {};
                      final authorName = (raw['userName'] ?? 'User') as String;
                      final authorId = _extractUserId(raw);
                      final avatar = (raw['userAvatar'] ?? '') as String;
                      final body = (raw['content'] ?? '').toString();
                      final right = _shortFromTs(raw['timestamp']);
                      final subtitle = '${right} ago';
                      final imageUrl = (raw['imageUrl'] ?? '').toString();
                      final videoUrl = (raw['videoUrl'] ?? '').toString();
                      final videoThumbUrl = (raw['videoThumbUrl'] ?? '').toString();
                      final aspect = (() {
                        final v = raw['mediaAspectRatio'];
                        if (v is num && v > 0) return v.toDouble();
                        return imageUrl.isNotEmpty ? (16 / 9) : 1.0;
                      })();

                      final isOwnPost = (authorId == currentUid);

                      return _PostCell(
                        authorName: authorName,
                        authorAvatarUrl: avatar,
                        subtitle: subtitle,
                        rightTime: right,
                        body: body,
                        imageUrl: imageUrl,
                        videoUrl: videoUrl,
                        videoThumbUrl: videoThumbUrl,
                        mediaAspect: aspect,
                        onOpenProfile: authorId.isEmpty
                            ? null
                            : () {
                                Navigator.of(context, rootNavigator: true).push(
                                  MaterialPageRoute(
                                    builder: (_) => ProfileScreen(userID: authorId),
                                  ),
                                );
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
                        onOpenImage: imageUrl.isEmpty
                            ? null
                            : () {
                                Navigator.of(context, rootNavigator: true).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          PostImageViewer(url: imageUrl)),
                                );
                              },
                        onOpenVideo: videoUrl.isEmpty
                            ? null
                            : () {
                                Navigator.of(context, rootNavigator: true).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          PostVideoPlayer(url: videoUrl)),
                                );
                              },
                        showConnect: !isOwnPost,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Top bar =====
class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.displaySmall;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          Text('Home', style: titleStyle),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              color: AppColors.chip,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded,
                  color: AppColors.primary),
              tooltip: 'Messages',
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(builder: (_) => const MessagesScreen()),
                );
              },
            ),
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

  Future<void> _markConnectionsSeen(String uid) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'lastConnectionsSeenAt': FieldValue.serverTimestamp()},
              SetOptions(merge: true));
    } catch (_) {
      // ignore UI errors
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: const [AppShadows.soft],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border:
              Border.all(color: AppColors.border.withOpacity(0.5), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome, $name',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            _TaupePill(
                icon: Icons.search,
                label: 'Find a helper',
                onTap: onFindHelper),
            const SizedBox(height: 12),

            // ✅ My Connections with live badge based on lastConnectionsSeenAt
            if (uid != null)
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .snapshots(),
                builder: (context, userSnap) {
                  DateTime? lastSeen;
                  if (userSnap.hasData) {
                    final d = userSnap.data!.data() as Map<String, dynamic>?;
                    lastSeen = parseFirestoreTimestamp(d?['lastConnectionsSeenAt']);
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('connections')
                        .where('users', arrayContains: uid) // we store 'users': [a,b]
                        .snapshots(),
                    builder: (context, connSnap) {
                      int recentCount = 0;
                      if (connSnap.hasData) {
                        for (final doc in connSnap.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final connectedAt = parseFirestoreTimestamp(data['connectedAt']);
                          if (connectedAt == null) continue;
                          // Count only items newer than lastSeen; if lastSeen is null, count all
                          if (lastSeen == null || connectedAt.isAfter(lastSeen!)) {
                            recentCount++;
                          }
                        }
                      }

                      return Stack(
                        children: [
                          _TaupePill(
                            icon: Icons.people_alt_outlined,
                            label: 'My connections',
                            onTap: () async {
                              // Mark as seen BEFORE navigating, so badge clears on return
                              await _markConnectionsSeen(uid);
                              // Navigate to Connections
                              // ignore: use_build_context_synchronously
                              Navigator.of(context, rootNavigator: true).push(
                                MaterialPageRoute(
                                    builder: (_) => const ConnectionsScreen()),
                              );
                            },
                          ),
                          if (recentCount > 0)
                            Positioned(
                              right: 14,
                              top: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$recentCount',
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
  const _TaupePill(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.button,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: AppColors.muted, size: 22),
              const SizedBox(width: 12),
              Text(label,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text)),
            ],
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

// ===== Post cell =====
class _PostCell extends StatefulWidget {
  final String authorName;
  final String authorAvatarUrl;
  final String subtitle;
  final String rightTime;
  final String body;
  final String imageUrl;
  final String videoUrl;
  final String videoThumbUrl;
  final double mediaAspect;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onConnect;
  final VoidCallback? onOpenImage;
  final VoidCallback? onOpenVideo;
  final bool showConnect;

  const _PostCell({
    required this.authorName,
    required this.authorAvatarUrl,
    required this.subtitle,
    required this.rightTime,
    required this.body,
    required this.imageUrl,
    required this.videoUrl,
    required this.videoThumbUrl,
    required this.mediaAspect,
    required this.onOpenProfile,
    required this.onConnect,
    required this.onOpenImage,
    required this.onOpenVideo,
    required this.showConnect,
  });

  @override
  State<_PostCell> createState() => _PostCellState();
}

class _PostCellState extends State<_PostCell> {
  static const _collapsedLines = 5;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = AppColors.border.withOpacity(0.65);
    Widget? media() {
      if (widget.imageUrl.isNotEmpty) {
        return _MediaImage(
            url: widget.imageUrl,
            aspect: widget.mediaAspect,
            onTap: widget.onOpenImage);
      }
      if (widget.videoUrl.isNotEmpty) {
        return _MediaVideoThumb(
          thumbUrl: widget.videoThumbUrl,
          aspect: widget.mediaAspect,
          onPlay: widget.onOpenVideo,
        );
      }
      return null;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: const [AppShadows.soft],
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _PostHeader(
              authorName: widget.authorName,
              subtitle: widget.subtitle,
              rightTime: widget.rightTime,
              avatarUrl: widget.authorAvatarUrl,
              onTap: widget.onOpenProfile),
          if (widget.body.isNotEmpty) const SizedBox(height: 12),
          if (widget.body.isNotEmpty)
            _ExpandableText(
              content: widget.body,
              expanded: _expanded,
              maxLinesWhenCollapsed: _collapsedLines,
              onToggle: () => setState(() => _expanded = !_expanded),
            ),
          if (media() != null) const SizedBox(height: 10),
          if (media() != null) media()!,
          if (widget.showConnect) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: widget.onConnect,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                backgroundColor: AppColors.button,
                foregroundColor: AppColors.text,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm)),
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              child: const Text('Connect'),
            ),
          ],
        ]),
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  final String authorName;
  final String subtitle;
  final String rightTime;
  final String avatarUrl;
  final VoidCallback? onTap;
  const _PostHeader(
      {required this.authorName,
      required this.subtitle,
      required this.rightTime,
      required this.avatarUrl,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final row = Row(children: [
      _Avatar(url: avatarUrl, radius: 20),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(authorName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.text)),
          const SizedBox(height: 2),
          Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 14, color: AppColors.muted)),
        ]),
      ),
      const SizedBox(width: 8),
      Text(rightTime,
          style: const TextStyle(fontSize: 14, color: AppColors.muted)),
    ]);
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

// ===== Shared widgets =====
class _ExpandableText extends StatelessWidget {
  final String content;
  final bool expanded;
  final int maxLinesWhenCollapsed;
  final VoidCallback onToggle;
  const _ExpandableText(
      {required this.content,
      required this.expanded,
      required this.maxLinesWhenCollapsed,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 16, height: 1.4, color: AppColors.text);
    return LayoutBuilder(builder: (ctx, constraints) {
      final tp = TextPainter(
        text: TextSpan(text: content, style: style),
        textDirection: TextDirection.ltr,
        maxLines: maxLinesWhenCollapsed,
      )..layout(maxWidth: constraints.maxWidth);
      final hasOverflow = tp.didExceedMaxLines;
      if (!hasOverflow) return Text(content, style: style);
      if (expanded) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content, style: style),
            const SizedBox(height: 6),
            _ShowMoreButton(expanded: true, onTap: onToggle),
          ],
        );
      }
      return Stack(children: [
        Text(content,
            style: style,
            maxLines: maxLinesWhenCollapsed,
            overflow: TextOverflow.clip),
        Positioned(
          left: 0,
          right: 0,
          bottom: 28,
          child: IgnorePointer(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.card.withOpacity(0.0),
                    AppColors.card.withOpacity(0.95),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
            bottom: 0,
            left: 0,
            child: _ShowMoreButton(expanded: false, onTap: onToggle)),
      ]);
    });
  }
}

class _ShowMoreButton extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;
  const _ShowMoreButton({required this.expanded, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.button,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(expanded ? 'Show less' : 'Show more',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.text)),
          ),
        ),
      );
}

class _MediaImage extends StatelessWidget {
  final String url;
  final double aspect;
  final VoidCallback? onTap;
  const _MediaImage({required this.url, required this.aspect, this.onTap});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: aspect,
          child: InkWell(
            onTap: onTap,
            child: Image.network(url,
                fit: BoxFit.cover,
                loadingBuilder: (c, w, p) =>
                    p == null ? w : Container(color: AppColors.button),
                errorBuilder: (_, __, ___) => Container(
                      color: AppColors.button,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image,
                          color: AppColors.muted),
                    )),
          ),
        ),
      );
}

class _MediaVideoThumb extends StatelessWidget {
  final String thumbUrl;
  final double aspect;
  final VoidCallback? onPlay;
  const _MediaVideoThumb(
      {required this.thumbUrl, required this.aspect, this.onPlay});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: aspect,
          child: Stack(fit: StackFit.expand, children: [
            if (thumbUrl.isNotEmpty)
              Image.network(thumbUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (c, w, p) =>
                      p == null ? w : Container(color: AppColors.button),
                  errorBuilder: (_, __, ___) =>
                      Container(color: AppColors.button))
            else
              Container(color: AppColors.button),
            Center(
              child: InkWell(
                onTap: onPlay,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow,
                      color: Colors.white, size: 36),
                ),
              ),
            ),
          ]),
        ),
      );
}

class _Avatar extends StatelessWidget {
  final String url;
  final double radius;
  const _Avatar({required this.url, this.radius = 20});
  @override
  Widget build(BuildContext context) => url.isEmpty
      ? CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.avatarBg,
          child:
              const Icon(Icons.person_outline, color: AppColors.avatarFg))
      : CircleAvatar(radius: radius, backgroundImage: NetworkImage(url));
}
