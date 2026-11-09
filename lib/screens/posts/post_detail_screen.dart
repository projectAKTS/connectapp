import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:connect_app/l10n/l10n.dart';
import 'package:connect_app/screens/posts/post_comments.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:connect_app/theme/tokens.dart';
import 'package:connect_app/widgets/full_screen_back_gesture.dart';
import 'package:connect_app/widgets/post_card.dart';

/// A post with its comments and a box to add one.
class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _composerFocus = FocusNode();

  @override
  void dispose() {
    _composerFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FullScreenBackGesture(
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          backgroundColor: AppColors.canvas,
          elevation: 0,
          title: Text(context.l10n.postDetailTitle),
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: HelperlyTestRuntime.firestore
              .collection('posts')
              .doc(widget.postId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!.data();
            if (data == null) {
              return Center(child: Text(context.l10n.postNotFound));
            }
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      PostCard(
                        postId: widget.postId,
                        data: data,
                        expandedByDefault: true,
                        onComment: _composerFocus.requestFocus,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        context.l10n.postCommentsTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      PostCommentsList(postId: widget.postId),
                    ],
                  ),
                ),
                CommentComposer(
                  postId: widget.postId,
                  focusNode: _composerFocus,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
