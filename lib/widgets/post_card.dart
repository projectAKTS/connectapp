import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:connect_app/l10n/formatters.dart';
import 'package:connect_app/l10n/l10n.dart';
import 'package:connect_app/l10n/value_labels.dart';
import 'package:connect_app/screens/profile/profile_screen.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:connect_app/services/safety_service.dart';
import 'package:connect_app/theme/tokens.dart';
import 'package:connect_app/utils/time_utils.dart';
import 'package:connect_app/widgets/initials_avatar.dart';
import 'package:connect_app/widgets/post_media.dart';
import 'package:connect_app/widgets/sensitive_media_cover.dart';

/// Author uid of a post, across the field names older builds used.
String postAuthorId(Map<String, dynamic> m) {
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

List<String> postImageUrls(Map<String, dynamic> raw) {
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

/// A post as the feed, profile and detail screens show it.
class PostCard extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> data;

  /// Called by Connect; no button without it (own posts, the detail screen).
  final VoidCallback? onConnect;

  /// Opens the post with its comments; null on the detail screen itself.
  final VoidCallback? onOpenDetail;

  /// The comment button on the detail screen (focuses the composer).
  final VoidCallback? onComment;

  /// The detail screen shows the full text.
  final bool expandedByDefault;

  const PostCard({
    super.key,
    required this.postId,
    required this.data,
    this.onConnect,
    this.onOpenDetail,
    this.onComment,
    this.expandedByDefault = false,
  });

  @override
  State<PostCard> createState() => PostCardState();
}

class PostCardState extends State<PostCard> {
  static const _collapsedLines = 7;
  late bool _expanded = widget.expandedByDefault;
  bool _helpfulBusy = false;
  String? _postStreamId;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _postStream;

  Map<String, dynamic> get raw => widget.data;
  String get _authorId => postAuthorId(raw);
  String get _authorName => (raw['userName'] ?? 'User').toString();
  bool get _isOwnPost =>
      _authorId.isNotEmpty && _authorId == HelperlyTestRuntime.currentUid;

  /// One listener per post for the card's lifetime, for Helpful and comment
  /// counts; the posts query emits on every like, which rebuilds every card.
  Stream<DocumentSnapshot<Map<String, dynamic>>> _currentPostStream() {
    if (_postStreamId != widget.postId || _postStream == null) {
      _postStreamId = widget.postId;
      _postStream = HelperlyTestRuntime.firestore
          .collection('posts')
          .doc(widget.postId)
          .snapshots();
    }
    return _postStream!;
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.postDeleteTitle),
        content: Text(context.l10n.postDeleteBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.commonCancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10n.commonDelete)),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .delete();
    if (mounted && widget.onOpenDetail == null)
      Navigator.of(context).maybePop();
  }

  Future<void> _onOtherPostAction(String action) async {
    if (action == 'report') {
      await SafetyService.instance.reportWithSheet(
        context,
        type: 'post',
        targetId: widget.postId,
        targetUid: _authorId,
      );
    } else if (action == 'block') {
      await SafetyService.instance.blockWithConfirm(
        context,
        targetUid: _authorId,
        name: _authorName,
      );
    }
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

  void _openProfile() {
    if (_authorId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileScreen(userID: _authorId)),
    );
  }

  Widget? _media() {
    final imageUrls = postImageUrls(raw);
    final videoUrl = (raw['videoUrl'] ?? '').toString();
    final sensitive = raw['sensitive'] == true && !_isOwnPost;
    final aspect = postMediaAspect(raw['mediaAspectRatio']);
    Widget? media;
    if (imageUrls.isNotEmpty) {
      media = PostPhotos(urls: imageUrls, aspect: aspect);
    } else if (videoUrl.isNotEmpty) {
      final ms = raw['videoDurationMs'];
      media = PostVideo(
        url: videoUrl,
        thumbUrl: (raw['videoThumbUrl'] ?? '').toString(),
        aspect: aspect,
        duration: ms is num ? Duration(milliseconds: ms.toInt()) : null,
      );
    } else {
      final status = (raw['mediaUploadStatus'] ?? '').toString();
      final started = parseFirestoreTimestamp(raw['mediaUploadStartedAt']);
      // An upload the app never finished (closed mid-way) counts as failed.
      final stale = started != null &&
          DateTime.now().difference(started) > const Duration(minutes: 20);
      final failed = status == 'failed' || (status == 'uploading' && stale);
      if (status == 'uploading' && !stale) {
        media = PostMediaPending(aspect: aspect, failed: false);
      } else if (failed && _isOwnPost) {
        media = PostMediaPending(aspect: aspect, failed: true);
      }
    }
    if (media == null || !sensitive) return media;
    return SensitiveMediaCover(
      label: context.l10n.postSensitiveTapToView,
      child: media,
    );
  }

  @override
  Widget build(BuildContext context) {
    final postedAt = parseFirestoreTimestamp(raw['timestamp']);
    final subtitle = postedAt == null
        ? context.l10n.timeNow
        : AppFormat.timeAgo(context, postedAt);
    final type = (raw['type'] ??
            raw['postType'] ??
            raw['templateType'] ??
            raw['template'] ??
            'Quick')
        .toString();
    final body = (raw['content'] ?? '').toString();
    final media = _media();
    final openDetail = widget.onOpenDetail;

    Widget tappable(Widget child) => openDetail == null
        ? child
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: openDetail,
            child: child,
          );

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
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
            authorName: _authorName,
            subtitle: subtitle,
            // "Quick post" is the default type: no badge for it.
            badge: ValueLabels.postType(context.l10n, type) ==
                    context.l10n.postTypeQuick
                ? ''
                : ValueLabels.postType(context.l10n, type),
            avatarUrl: (raw['userAvatar'] ?? '').toString(),
            onTap: _authorId.isEmpty ? null : _openProfile,
            trailing: _isOwnPost
                ? PopupMenuButton<String>(
                    tooltip: context.l10n.postOptions,
                    icon: const Icon(Icons.more_horiz, color: AppColors.muted),
                    onSelected: (_) => _confirmDelete(),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(context.l10n.commonDelete),
                      ),
                    ],
                  )
                : PopupMenuButton<String>(
                    tooltip: context.l10n.postOptions,
                    icon: const Icon(Icons.more_horiz, color: AppColors.muted),
                    onSelected: _onOtherPostAction,
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'report',
                        child: Text(context.l10n.postReport),
                      ),
                      if (_authorId.isNotEmpty)
                        PopupMenuItem(
                          value: 'block',
                          child:
                              Text(context.l10n.postBlockAuthor(_authorName)),
                        ),
                    ],
                  ),
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 10),
            tappable(_ExpandableStructuredText(
              content: body,
              expanded: _expanded,
              maxLinesWhenCollapsed: _collapsedLines,
              onToggle: () => setState(() => _expanded = !_expanded),
            )),
          ],
          if (media != null) ...[
            const SizedBox(height: 10),
            media,
          ],
          const SizedBox(height: 6),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _currentPostStream(),
            builder: (context, snap) {
              final data = snap.data?.data() ?? raw;
              int count(String key) =>
                  (data[key] is num) ? (data[key] as num).toInt() : 0;
              final likes = count('likes');
              final comments = count('commentsCount');
              final likedBy = ((data['likedBy'] as List?) ?? const [])
                  .map((e) => '$e')
                  .toSet();
              final uid = HelperlyTestRuntime.currentUid ?? '';
              final isHelpful = uid.isNotEmpty && likedBy.contains(uid);
              return Row(
                children: [
                  _ActionButton(
                    icon: isHelpful ? Icons.favorite : Icons.favorite_border,
                    label: context.l10n.postHelpful,
                    count: likes,
                    active: isHelpful,
                    // Rules refuse a Helpful on your own post: count only.
                    onTap: _isOwnPost || _helpfulBusy
                        ? null
                        : () => _toggleHelpful(isHelpful),
                  ),
                  const SizedBox(width: 4),
                  _ActionButton(
                    icon: Icons.mode_comment_outlined,
                    label: context.l10n.postComment,
                    count: comments,
                    onTap: widget.onComment ?? openDetail,
                  ),
                  const Spacer(),
                  if (widget.onConnect != null && !_isOwnPost)
                    OutlinedButton(
                      onPressed: widget.onConnect,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        minimumSize: const Size(0, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                      child: Text(context.l10n.actionConnect),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool active;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.count,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.muted;
    return Semantics(
      button: onTap != null,
      label: count > 0 ? '$label, $count' : label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 6),
              Text(
                count > 0 ? '$label · $count' : label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  final String authorName;
  final String subtitle;
  final String badge;
  final String avatarUrl;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _PostHeader({
    required this.authorName,
    required this.subtitle,
    required this.badge,
    required this.avatarUrl,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final who = Row(
      children: [
        InitialsAvatar(url: avatarUrl, name: authorName, radius: 20),
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
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  if (badge.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _PostTypeBadge(label: badge),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );

    return Row(
      children: [
        Expanded(
          child: onTap == null
              ? who
              : InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: who,
                ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _PostTypeBadge extends StatelessWidget {
  final String label;
  const _PostTypeBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withOpacity(0.12)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
          fontSize: 11.5,
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
    // Template prompts are short lines; a whole paragraph in bold is hard to read.
    if (t.isEmpty || t.length > 80) return false;
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
            expanded
                ? context.l10n.commonShowLess
                : context.l10n.commonShowMore,
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
