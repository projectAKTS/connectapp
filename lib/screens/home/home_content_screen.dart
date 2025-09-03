import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:connect_app/utils/time_utils.dart';
import 'package:connect_app/theme/tokens.dart';

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

class HomeContentScreen extends StatefulWidget {
  const HomeContentScreen({Key? key}) : super(key: key);

  @override
  State<HomeContentScreen> createState() => _HomeContentScreenState();
}

class _HomeContentScreenState extends State<HomeContentScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firstName = (user?.displayName ?? 'Maria').split(' ').first;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            const SliverToBoxAdapter(child: _HomeTopBar()),
            SliverToBoxAdapter(child: _WelcomeCard(name: firstName)),
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
                      final d = posts[i].data() as Map<String, dynamic>? ?? {};
                      final author = d['userName'] ?? 'User';
                      final avatar = d['userAvatar'] ?? '';
                      final body = (d['content'] ?? '').toString();
                      final right = _shortFromTs(d['timestamp']);
                      final subtitle = '${right} ago';

                      return _PostCell(
                        authorName: author,
                        authorAvatarUrl: avatar,
                        subtitle: subtitle,
                        rightTime: right,
                        body: body,
                        onConnect: () {
                          HapticFeedback.lightImpact();
                          // TODO: open chat or your connect flow
                        },
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
              icon: const Icon(Icons.person_outline, color: AppColors.primary),
              onPressed: () => Navigator.of(context).pushNamed('/profile/me'),
              tooltip: 'Profile',
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final String name;
  const _WelcomeCard({Key? key, required this.name}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Softer inner panel (closer to the mock)
    final innerColor = Colors.white.withOpacity(0.92);
    final innerBorder = AppColors.border.withOpacity(0.55);

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
          color: AppColors.canvas, // ✅ same pure white as background
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border.withOpacity(0.5), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome, $name', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            const _TaupePill(icon: Icons.search, label: 'Find a helper'),
            const SizedBox(height: 12),
            const _TaupePill(
              icon: Icons.event_available_outlined,
              label: 'Book a consultation',
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
  const _TaupePill({Key? key, required this.icon, required this.label})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
      ),
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
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _PostCell extends StatelessWidget {
  final String authorName;
  final String authorAvatarUrl;
  final String subtitle;   // “2h ago”
  final String rightTime;  // “2h”
  final String body;
  final VoidCallback onConnect;

  const _PostCell({
    Key? key,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.subtitle,
    required this.rightTime,
    required this.body,
    required this.onConnect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final borderColor = AppColors.border.withOpacity(0.65);

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
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            _Avatar(url: authorAvatarUrl, radius: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  authorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: AppColors.muted),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            Text(rightTime, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
          ]),

          const SizedBox(height: 12),

          Text(
            body,
            style: const TextStyle(fontSize: 16, height: 1.4, color: AppColors.text),
          ),

          const SizedBox(height: 12),

          TextButton(
            onPressed: onConnect,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              backgroundColor: AppColors.surface, // now lighter
              foregroundColor: AppColors.text,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ).copyWith(
              overlayColor:
                  MaterialStateProperty.all(AppColors.surface.withOpacity(0.7)),
            ),
            child: const Text('Connect'),
          ),
        ]),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String url;
  final double radius;
  const _Avatar({Key? key, required this.url, this.radius = 20}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.canvas,
        child: const Icon(Icons.person_outline, color: AppColors.primary),
      );
    }
    return CircleAvatar(radius: radius, backgroundImage: NetworkImage(url));
  }
}
