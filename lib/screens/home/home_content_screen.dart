import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // HapticFeedback
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../posts/comment_bottom_sheet.dart';
import '../posts/create_post_screen.dart';
import 'package:connect_app/services/post_service.dart';
import 'package:connect_app/utils/time_utils.dart';

/// =====================
/// Evergreen (Green) Design Tokens
/// =====================
class AppColors {
  // Brand
  static const primary = Color(0xFF0B5B47); // deep evergreen
  static const primaryTonal = Color(0xFFEAF5F1); // subtle mint surface

  // Semantic
  static const success = Color(0xFF198754); // helpful
  static const danger = Color(0xFFDC3545); // report / heart
  static const boosted = Color(0xFFB54708); // warm badge text
  static const boostedBg = Color(0xFFFFF4E5); // warm badge bg
  static const boostedBorder = Color(0xFFFFE8C7);

  // Neutrals
  static const text = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const card = Colors.white;
  static const canvas = Color(0xFFFAFAFB);
}

class HomeContentScreen extends StatefulWidget {
  const HomeContentScreen({Key? key}) : super(key: key);

  @override
  _HomeContentScreenState createState() => _HomeContentScreenState();
}

class _HomeContentScreenState extends State<HomeContentScreen> {
  final Map<String, int> helpfulVotesMap = {};
  final PostService _postService = PostService();
  final ScrollController _scrollController = ScrollController();

  // Helpers cache (for person suggestions)
  List<_HelperUser> _helpers = [];
  bool _loadingHelpers = true;

  @override
  void initState() {
    super.initState();
    _loadHelpers();
  }

  Future<void> _loadHelpers() async {
    try {
      final qs = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('helpfulMarks', descending: true)
          .limit(20)
          .get();

      _helpers = qs.docs.map((d) => _HelperUser.fromSnap(d)).toList();
    } catch (e) {
      debugPrint('Helpers load error: $e');
    } finally {
      if (mounted) setState(() => _loadingHelpers = false);
    }
  }

  // ===== UX helpers =====
  void _safeShowSnackBar(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _goToCreatePost() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );
    if (result == 'posted' && _scrollController.hasClients) {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  // ===== Post actions =====
  Future<void> _reportPost(BuildContext context, String postId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _safeShowSnackBar('You need to be logged in to report posts.');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Post'),
        content: const Text('Are you sure you want to report this post?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Report')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('reports').add({
          'postId': postId,
          'reportedBy': currentUser.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });
        _safeShowSnackBar('Post reported. Thank you for your feedback.');
      } catch (e) {
        _safeShowSnackBar('Error reporting post: $e');
      }
    }
  }

  Future<void> _toggleLike(BuildContext context, String postId, List<String> likedBy) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _safeShowSnackBar('You need to be logged in to like posts.');
      return;
    }
    final uid = currentUser.uid;
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

    try {
      await FirebaseFirestore.instance.runTransaction((t) async {
        final snap = await t.get(postRef);
        if (!snap.exists) return;
        final data = snap.data() as Map<String, dynamic>;
        final liked = List.from(data['likedBy'] ?? <String>[]);
        final likes = (data['likes'] ?? 0) as int;

        if (liked.contains(uid)) {
          t.update(postRef, {
            'likes': likes - 1,
            'likedBy': FieldValue.arrayRemove([uid]),
          });
        } else {
          t.update(postRef, {
            'likes': likes + 1,
            'likedBy': FieldValue.arrayUnion([uid]),
          });
        }
      });
    } catch (e) {
      _safeShowSnackBar('Error toggling like: $e');
    }
  }

  Future<void> _markHelpful(BuildContext context, String postId, String postOwnerId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _safeShowSnackBar('You need to be logged in to mark as helpful.');
      return;
    }
    final userId = currentUser.uid;
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    final ownerRef = FirebaseFirestore.instance.collection('users').doc(postOwnerId);

    try {
      final userSnap = await userRef.get();
      if (!userSnap.exists) {
        _safeShowSnackBar('User document not found.');
        return;
      }
      final votes = userSnap['helpfulVotesGiven'] ?? [];
      final hasVoted = (votes as List).any((v) => v['postId'] == postId);

      setState(() {
        final current = helpfulVotesMap[postId] ?? 0;
        helpfulVotesMap[postId] = hasVoted ? (current > 0 ? current - 1 : 0) : current + 1;
      });

      if (hasVoted) {
        await FirebaseFirestore.instance.runTransaction((t) async {
          t.update(userRef, {
            'helpfulVotesGiven': FieldValue.arrayRemove([
              {'postId': postId, 'date': DateTime.now().toString().substring(0, 10)}
            ]),
          });
          t.update(postRef, {'helpfulVotes': FieldValue.increment(-1)});
          t.update(ownerRef, {
            'xpPoints': FieldValue.increment(-10),
            'helpfulMarks': FieldValue.increment(-1),
          });
        });
        _safeShowSnackBar('Helpful vote removed.');
      } else {
        final todayCount = (votes as List)
            .where((v) => v['date'] == DateTime.now().toString().substring(0, 10))
            .length;
        if (todayCount >= 5) {
          setState(() {
            final current = helpfulVotesMap[postId] ?? 1;
            helpfulVotesMap[postId] = current > 0 ? current - 1 : 0;
          });
          _safeShowSnackBar('You can only mark 5 posts as helpful per day.');
          return;
        }

        await FirebaseFirestore.instance.runTransaction((t) async {
          t.update(userRef, {
            'helpfulVotesGiven': FieldValue.arrayUnion([
              {'postId': postId, 'date': DateTime.now().toString().substring(0, 10)}
            ]),
          });
          t.update(postRef, {'helpfulVotes': FieldValue.increment(1)});
          t.update(ownerRef, {
            'xpPoints': FieldValue.increment(10),
            'helpfulMarks': FieldValue.increment(1),
          });
        });
        _safeShowSnackBar('Post marked as helpful!');
      }
    } catch (e) {
      setState(() {
        final current = helpfulVotesMap[postId] ?? 0;
        if (current > 0) helpfulVotesMap[postId] = current - 1;
      });
      _safeShowSnackBar('Error marking helpful: $e');
    }
  }

  Future<void> _boostPost(BuildContext context, String postId) async {
    try {
      await _postService.boostPost(postId, 6);
      _safeShowSnackBar('Post boosted successfully for 6 hours!');
    } catch (e) {
      _safeShowSnackBar('Error boosting post: $e');
    }
  }

  // PersonCard actions
  void _openChat(String otherUserId) {
    Navigator.of(context).pushNamed('/chat', arguments: {'otherUserId': otherUserId});
  }

  void _openConsultation(_HelperUser h) {
    Navigator.of(context).pushNamed('/consultation', arguments: {
      'targetUserId': h.uid,
      'targetUserName': h.name,
      'ratePerMinute': h.ratePerMinute,
    });
  }

  void _showConnectSheet(_HelperUser h) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('Message'),
                onTap: () {
                  Navigator.pop(context);
                  _openChat(h.uid);
                },
              ),
              ListTile(
                leading: const Icon(Icons.call_outlined),
                title: const Text('Audio consultation'),
                onTap: () {
                  Navigator.pop(context);
                  _openConsultation(h);
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('Video consultation'),
                onTap: () {
                  Navigator.pop(context);
                  _openConsultation(h);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      floatingActionButton: FloatingActionButton(
        onPressed: _goToCreatePost,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('isBoosted', descending: true)
            .orderBy('boostScore', descending: true)
            .orderBy('helpfulVotes', descending: true)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SafeArea(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    _SearchHeader(),
                    SizedBox(height: 24),
                    Center(child: CircularProgressIndicator()),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const SafeArea(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    _SearchHeader(),
                    SizedBox(height: 24),
                    Text('No posts yet! Create one to get started.'),
                  ],
                ),
              ),
            );
          }

          final posts = snapshot.data!.docs;

          // Build feed: Every 3 posts → insert a PersonCard
          final List<Widget> feed = [];
          int helperIndex = 0;

          for (int i = 0; i < posts.length; i++) {
            final post = posts[i];
            final Map<String, dynamic> data = post.data() as Map<String, dynamic>? ?? {};
            final postId = post.id;

            final postOwnerId = data['userID'] ?? 'unknown_user';
            final userName = data['userName'] ?? 'Unknown User';
            final content = data['content'] ?? '';
            final imageUrl = data['imageUrl'] ?? '';
            final likedBy = (data['likedBy'] != null)
                ? List<String>.from(data['likedBy'])
                : <String>[];
            final likes = data['likes'] ?? 0;
            final dbHelpfulVotes = data['helpfulVotes'] ?? 0;
            final localHelpful = helpfulVotesMap[postId] ?? dbHelpfulVotes;
            final helpfulVotes = (localHelpful < 0) ? 0 : localHelpful;
            final isBoosted = data['isBoosted'] ?? false;

            String formattedTime = 'Just now';
            final dt = parseFirestoreTimestamp(data['timestamp']);
            if (dt != null) {
              formattedTime = DateFormat('MMM d, yyyy · hh:mm a').format(dt);
            }

            final isLiked = likedBy.contains(currentUserId);

            if ((imageUrl).toString().isNotEmpty) {
              // Image post card
              feed.add(
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: _PostCardEvergreen(
                    authorName: userName,
                    authorSubtitle: data['authorRole'] ?? data['location'] ?? '',
                    title: content,
                    summary: '',
                    timeRight: formattedTime,
                    boosted: isBoosted,
                    likes: likes,
                    helpfulCount: helpfulVotes,
                    isLiked: isLiked,
                    imageUrl: imageUrl,
                    onAskAuthor: () {
                      HapticFeedback.lightImpact();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => CommentBottomSheet(postId: postId),
                      );
                    },
                    onViewProfile: () => Navigator.of(context).pushNamed('/profile/$postOwnerId'),
                    onLike: () => _toggleLike(context, postId, likedBy),
                    onHelpful: () => _markHelpful(context, postId, postOwnerId),
                    onReport: () => _reportPost(context, postId),
                    onBoost: (currentUserId == postOwnerId && !isBoosted)
                        ? () => _boostPost(context, postId)
                        : null,
                  ),
                ),
              );
            } else {
              // Text-only: big, minimal card (auto-height + “More” expander)
              feed.add(
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: _PostCardSimpleFocus(
                    authorName: userName,
                    authorSubtitle: data['authorRole'] ?? data['location'] ?? '',
                    body: content,
                    boosted: isBoosted,
                    timeRight: formattedTime,
                    likes: likes,
                    helpfulCount: helpfulVotes,
                    isLiked: isLiked,
                    onAskAuthor: () {
                      HapticFeedback.lightImpact();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => CommentBottomSheet(postId: postId),
                      );
                    },
                    onViewProfile: () => Navigator.of(context).pushNamed('/profile/$postOwnerId'),
                    onLike: () => _toggleLike(context, postId, likedBy),
                    onHelpful: () => _markHelpful(context, postId, postOwnerId),
                    onReport: () => _reportPost(context, postId),
                    onBoost: (currentUserId == postOwnerId && !isBoosted)
                        ? () => _boostPost(context, postId)
                        : null,
                  ),
                ),
              );
            }

            if (_helpers.isNotEmpty && ((i + 1) % 3 == 0)) {
              final h = _helpers[helperIndex % _helpers.length];
              helperIndex++;
              feed.add(
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: _PersonCardCompact(
                    helper: h,
                    onConnect: () => _showConnectSheet(h),
                    onMessage: () => _openChat(h.uid),
                    onViewProfile: () => Navigator.of(context).pushNamed('/profile/${h.uid}'),
                  ),
                ),
              );
            }
          }

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              const SliverToBoxAdapter(child: SafeArea(child: _SearchHeader())),
              SliverList(delegate: SliverChildListDelegate(feed)),
              if (_loadingHelpers)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          );
        },
      ),
    );
  }
}

/// =====================
/// UI: Minimal green search
/// =====================
class _SearchHeader extends StatelessWidget {
  const _SearchHeader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        readOnly: true,
        onTap: () {
          // TODO: navigate to Search screen
        },
        decoration: InputDecoration(
          hintText: 'What are you stuck on?',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: AppColors.card,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

/// =====================
/// Evergreen Post Card — image posts (no full-screen)
/// =====================
class _PostCardEvergreen extends StatelessWidget {
  final String authorName;
  final String authorSubtitle;
  final String title;
  final String summary;
  final String timeRight;
  final bool boosted;
  final int likes;
  final int helpfulCount;
  final bool isLiked;
  final String imageUrl;

  final VoidCallback onAskAuthor;
  final VoidCallback onLike;
  final VoidCallback onHelpful;
  final VoidCallback onReport;
  final VoidCallback? onBoost;
  final VoidCallback onViewProfile;

  const _PostCardEvergreen({
    Key? key,
    required this.authorName,
    required this.authorSubtitle,
    required this.title,
    required this.summary,
    required this.timeRight,
    required this.boosted,
    required this.likes,
    required this.helpfulCount,
    required this.isLiked,
    required this.imageUrl,
    required this.onAskAuthor,
    required this.onLike,
    required this.onHelpful,
    required this.onReport,
    required this.onViewProfile,
    this.onBoost,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14111827),
            blurRadius: 18,
            offset: Offset(0, 10),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header with capped Boosted tag and date
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            const CircleAvatar(radius: 18, child: Icon(Icons.person_outline, color: AppColors.primary)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(
                      authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.text),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.verified, size: 16, color: AppColors.primary),
                ]),
                if (authorSubtitle.isNotEmpty) const SizedBox(height: 2),
                if (authorSubtitle.isNotEmpty)
                  Text(authorSubtitle, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ]),
            ),
            const SizedBox(width: 8),
            Flexible(
              fit: FlexFit.loose,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (boosted) const _BoostedTag(),
                  if (boosted) const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      timeRight,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
          ]),

          const SizedBox(height: 12),

          // Image hero (non-interactive)
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 180,
                  color: AppColors.primaryTonal,
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_not_supported, color: AppColors.muted),
                ),
              ),
            ),

          if (title.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.25,
                color: AppColors.text,
              ),
            ),
          ],
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              summary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, height: 1.35, color: AppColors.text),
            ),
          ],

          const SizedBox(height: 12),

          // Primary CTA
          SizedBox(
            height: 48,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                onAskAuthor();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              child: Text('Ask $authorName about this'),
            ),
          ),

          const SizedBox(height: 10),

          // Meta row
          Row(children: [
            TextButton(
              onPressed: onViewProfile,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.text,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontWeight: FontWeight.w500),
              ),
              child: const Text('View profile'),
            ),
            const Spacer(),
            Text(timeRight, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),

          const SizedBox(height: 6),

          // Actions — hide zero labels
          Row(children: [
            IconButton(
              icon: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? AppColors.danger : AppColors.muted.withOpacity(0.6),
              ),
              onPressed: onLike,
              tooltip: 'Like',
            ),
            if (likes > 0)
              Text('$likes', style: TextStyle(color: AppColors.muted.withOpacity(0.85))),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                helpfulCount > 0 ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
                color: helpfulCount > 0 ? AppColors.success : AppColors.muted.withOpacity(0.6),
              ),
              onPressed: onHelpful,
              tooltip: 'Helpful',
            ),
            if (helpfulCount > 0)
              Text('$helpfulCount', style: TextStyle(color: AppColors.muted.withOpacity(0.85))),
            const Spacer(),
            if (onBoost != null)
              IconButton(
                icon: const Icon(Icons.rocket_launch, color: AppColors.boosted),
                onPressed: onBoost,
                tooltip: 'Boost',
              ),
            IconButton(
              icon: const Icon(Icons.flag, color: AppColors.danger),
              onPressed: onReport,
              tooltip: 'Report',
            ),
          ]),
        ]),
      ),
    );
  }
}

/// =====================
/// Simple Focus Card — text-only posts (auto-height, “More”)
/// =====================
class _PostCardSimpleFocus extends StatefulWidget {
  final String authorName;
  final String authorSubtitle;
  final String body;
  final bool boosted;
  final String timeRight;
  final int likes;
  final int helpfulCount;
  final bool isLiked;

  final VoidCallback onAskAuthor;
  final VoidCallback onLike;
  final VoidCallback onHelpful;
  final VoidCallback onReport;
  final VoidCallback? onBoost;
  final VoidCallback onViewProfile;

  const _PostCardSimpleFocus({
    Key? key,
    required this.authorName,
    required this.authorSubtitle,
    required this.body,
    required this.boosted,
    required this.timeRight,
    required this.likes,
    required this.helpfulCount,
    required this.isLiked,
    required this.onAskAuthor,
    required this.onLike,
    required this.onHelpful,
    required this.onReport,
    required this.onViewProfile,
    this.onBoost,
  }) : super(key: key);

  @override
  State<_PostCardSimpleFocus> createState() => _PostCardSimpleFocusState();
}

class _PostCardSimpleFocusState extends State<_PostCardSimpleFocus> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    const double minCardHeight = 220;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: minCardHeight),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14111827),
              blurRadius: 26,
              offset: Offset(0, 14),
              spreadRadius: -6,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header (quiet)
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryTonal,
                child: Icon(Icons.person_outline, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: Text(
                        widget.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, size: 16, color: AppColors.primary),
                  ]),
                  if (widget.authorSubtitle.isNotEmpty) const SizedBox(height: 2),
                  if (widget.authorSubtitle.isNotEmpty)
                    Text(widget.authorSubtitle, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ]),
              ),
              const SizedBox(width: 8),
              Flexible(
                fit: FlexFit.loose,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.boosted) const _BoostedTag(),
                    if (widget.boosted) const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.timeRight,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ]),

            const SizedBox(height: 14),

            // Headline/body with expander
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  widget.body,
                  maxLines: expanded ? 999 : 3,
                  overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: AppColors.text,
                  ),
                ),
                if (!expanded && widget.body.trim().length > 120)
                  TextButton(
                    onPressed: () => setState(() => expanded = true),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: AppColors.primary,
                    ),
                    child: const Text('More'),
                  ),
              ]),
            ),

            const SizedBox(height: 16),

            // Primary CTA
            SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  widget.onAskAuthor();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                child: Text('Ask ${widget.authorName} about this'),
              ),
            ),

            const SizedBox(height: 10),

            // Meta + actions (hide zero labels)
            Row(children: [
              TextButton(
                onPressed: widget.onViewProfile,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.text.withOpacity(0.9),
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('View profile'),
              ),
              const Spacer(),

              IconButton(
                icon: Icon(
                  widget.isLiked ? Icons.favorite : Icons.favorite_border,
                  color: widget.isLiked ? AppColors.danger : AppColors.muted.withOpacity(0.6),
                ),
                onPressed: widget.onLike,
                tooltip: 'Like',
              ),
              if (widget.likes > 0)
                Text('${widget.likes}', style: TextStyle(color: AppColors.muted.withOpacity(0.85))),
              const SizedBox(width: 8),

              IconButton(
                icon: Icon(
                  widget.helpfulCount > 0 ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
                  color: widget.helpfulCount > 0 ? AppColors.success : AppColors.muted.withOpacity(0.6),
                ),
                onPressed: widget.onHelpful,
                tooltip: 'Helpful',
              ),
              if (widget.helpfulCount > 0)
                Text('${widget.helpfulCount}', style: TextStyle(color: AppColors.muted.withOpacity(0.85))),

              if (widget.onBoost != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.rocket_launch, color: AppColors.boosted),
                  onPressed: widget.onBoost,
                  tooltip: 'Boost',
                ),
              ],
              const SizedBox(width: 2),
              IconButton(
                icon: const Icon(Icons.flag, color: AppColors.danger),
                onPressed: widget.onReport,
                tooltip: 'Report',
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// =====================
/// Boosted Tag (capped width, compact)
/// =====================
class _BoostedTag extends StatelessWidget {
  const _BoostedTag({super.key});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 92),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.boostedBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.boostedBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.rocket_launch, size: 12, color: AppColors.boosted),
            SizedBox(width: 4),
            Flexible(
              child: Text(
                'Boosted',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: AppColors.boosted, height: 1.0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// =====================
/// Small pieces
/// =====================
class _StatButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _StatButton({Key? key, required this.icon, required this.color, required this.label, required this.onTap})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Row(children: [
        Icon(icon, size: 20, color: color),
        if (label.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.text)),
        ],
      ]),
    );
  }
}

/// =====================
/// UI: Compact Person card
/// =====================
class _PersonCardCompact extends StatelessWidget {
  final _HelperUser helper;
  final VoidCallback onConnect;
  final VoidCallback onMessage;
  final VoidCallback onViewProfile;

  const _PersonCardCompact({
    Key? key,
    required this.helper,
    required this.onConnect,
    required this.onMessage,
    required this.onViewProfile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14111827),
            blurRadius: 20,
            offset: Offset(0, 10),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _Avatar(url: helper.photoUrl, radius: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(helper.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.text)),
                Text(
                  helper.tagline.isNotEmpty ? helper.tagline : 'Available to help',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ]),
            ),
            IconButton(icon: const Icon(Icons.person_outline), onPressed: onViewProfile, tooltip: 'Profile'),
          ]),

          const SizedBox(height: 12),

          Row(children: [
            Expanded(
              child: ElevatedButton(
                onPressed: onConnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                child: const Text('Connect'),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: onMessage,
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('Message'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                foregroundColor: AppColors.text,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ]),

          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.thumb_up_alt_outlined, size: 16, color: AppColors.success),
            const SizedBox(width: 6),
            Text('${helper.helpfulMarks} helpful marks', style: const TextStyle(color: AppColors.muted)),
            const Spacer(),
            if (helper.ratePerMinute > 0)
              Text('\$${helper.ratePerMinute}/min',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
          ]),
        ]),
      ),
    );
  }
}

/// =====================
/// Avatar + Helper model
/// =====================
class _Avatar extends StatelessWidget {
  final String url;
  final double radius;
  const _Avatar({Key? key, required this.url, this.radius = 20}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return const CircleAvatar(
        radius: 20,
        child: Icon(Icons.person_outline, color: AppColors.primary),
      );
    }
    return CircleAvatar(radius: radius, backgroundImage: NetworkImage(url));
  }
}

class _HelperUser {
  final String uid;
  final String name;
  final String photoUrl;
  final String tagline;
  final List<dynamic> skills;
  final int helpfulMarks;
  final int ratePerMinute;

  _HelperUser({
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.tagline,
    required this.skills,
    required this.helpfulMarks,
    required this.ratePerMinute,
  });

  factory _HelperUser.fromSnap(DocumentSnapshot snap) {
    final d = (snap.data() as Map<String, dynamic>? ?? {});
    return _HelperUser(
      uid: snap.id,
      name: d['fullName'] ?? d['name'] ?? 'User',
      photoUrl: d['profilePicture'] ?? '',
      tagline: d['bio'] ?? d['role'] ?? d['location'] ?? '',
      skills: d['skills'] ?? d['interestTags'] ?? const [],
      helpfulMarks: (d['helpfulMarks'] ?? 0) is int
          ? (d['helpfulMarks'] ?? 0) as int
          : int.tryParse('${d['helpfulMarks']}') ?? 0,
      ratePerMinute: (d['ratePerMinute'] ?? 0) is int
          ? (d['ratePerMinute'] ?? 0) as int
          : int.tryParse('${d['ratePerMinute']}') ?? 0,
    );
  }
}
