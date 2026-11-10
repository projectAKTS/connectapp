import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:connect_app/l10n/formatters.dart';
import 'package:connect_app/l10n/l10n.dart';
import 'package:connect_app/screens/profile/profile_screen.dart';
import 'package:connect_app/services/content_filter.dart';
import 'package:connect_app/services/firestore_read_helper.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:connect_app/services/safety_service.dart';
import 'package:connect_app/theme/tokens.dart';
import 'package:connect_app/utils/time_utils.dart';
import 'package:connect_app/widgets/initials_avatar.dart';

CollectionReference<Map<String, dynamic>> _comments(String postId) =>
    HelperlyTestRuntime.firestore
        .collection('posts')
        .doc(postId)
        .collection('comments');

/// Comments under a post, oldest first, without people the reader blocked.
class PostCommentsList extends StatelessWidget {
  final String postId;
  const PostCommentsList({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: SafetyService.instance.blocked,
      builder: (context, blocked, _) =>
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _comments(postId)
            .orderBy('timestamp')
            .limitToLast(200)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final docs = snap.data!.docs.where((d) {
            final uid = '${d.data()['userID'] ?? d.data()['userId'] ?? ''}';
            return !blocked.contains(uid);
          }).toList();
          if (docs.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                context.l10n.commentNone,
                style: const TextStyle(color: AppColors.muted),
              ),
            );
          }
          return Column(
            children: [
              for (final d in docs)
                _CommentTile(postId: postId, id: d.id, data: d.data()),
            ],
          );
        },
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final String postId;
  final String id;
  final Map<String, dynamic> data;
  const _CommentTile(
      {required this.postId, required this.id, required this.data});

  String get _uid => '${data['userID'] ?? data['userId'] ?? ''}';

  Future<void> _onAction(BuildContext context, String action) async {
    final name = '${data['authorName'] ?? data['userName'] ?? ''}';
    switch (action) {
      case 'delete':
        await _comments(postId).doc(id).delete();
      case 'report':
        await SafetyService.instance.reportWithSheet(
          context,
          type: 'comment',
          targetId: '$postId/$id',
          targetUid: _uid,
        );
      case 'block':
        await SafetyService.instance
            .blockWithConfirm(context, targetUid: _uid, name: name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = '${data['authorName'] ?? data['userName'] ?? ''}'.trim();
    final text = '${data['text'] ?? data['content'] ?? ''}';
    final at = parseFirestoreTimestamp(data['timestamp']);
    final mine = _uid.isNotEmpty && _uid == HelperlyTestRuntime.currentUid;
    final displayName = name.isEmpty ? context.l10n.commonUser : name;

    void openProfile() {
      if (_uid.isEmpty) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProfileScreen(userID: _uid)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: openProfile,
            child: InitialsAvatar(
              url: '${data['authorAvatar'] ?? ''}',
              name: displayName,
              radius: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: BoxDecoration(
                color: AppColors.button,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: GestureDetector(
                          onTap: openProfile,
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        at == null
                            ? context.l10n.commentJustNow
                            : AppFormat.timeAgo(context, at),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.3,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: context.l10n.postOptions,
            icon: const Icon(Icons.more_vert, size: 18, color: AppColors.muted),
            onSelected: (a) => _onAction(context, a),
            itemBuilder: (_) => mine
                ? [
                    PopupMenuItem(
                        value: 'delete',
                        child: Text(context.l10n.commentDelete)),
                  ]
                : [
                    PopupMenuItem(
                        value: 'report',
                        child: Text(context.l10n.commentReport)),
                    if (_uid.isNotEmpty)
                      PopupMenuItem(
                        value: 'block',
                        child: Text(context.l10n.postBlockAuthor(displayName)),
                      ),
                  ],
          ),
        ],
      ),
    );
  }
}

/// The "Write a comment" bar at the bottom of a post.
class CommentComposer extends StatefulWidget {
  final String postId;
  final FocusNode focusNode;
  const CommentComposer(
      {super.key, required this.postId, required this.focusNode});

  @override
  State<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<CommentComposer> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final uid = HelperlyTestRuntime.currentUid ?? '';
    if (text.isEmpty || uid.isEmpty || _sending) return;
    if (!ContentFilter.isAllowed(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.contentRejected)),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final me = await FirestoreReadHelper.getDoc(
        HelperlyTestRuntime.firestore.collection('users').doc(uid),
      );
      final profile = me.data() ?? const <String, dynamic>{};
      final name = '${profile['displayName'] ?? profile['fullName'] ?? ''}'
          .trim();
      await _comments(widget.postId).add({
        'userID': uid,
        'authorName':
            name.isNotEmpty ? name : (HelperlyTestRuntime.currentDisplayName ?? ''),
        'authorAvatar': '${profile['profilePicture'] ?? ''}',
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _controller.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.commentFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _controller.text.trim().isNotEmpty && !_sending;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: widget.focusNode,
                minLines: 1,
                maxLines: 4,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: context.l10n.commentHint,
                  counterText: '',
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.button,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: context.l10n.commentSend,
              onPressed: canSend ? _send : null,
              icon: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.send_rounded,
                      color: canSend ? AppColors.primary : AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
