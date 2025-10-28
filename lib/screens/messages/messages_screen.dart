// lib/screens/messages/messages_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connect_app/theme/tokens.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        title: const Text(
          'Messages',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUser?.uid)
            .orderBy('lastMessageTime', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No messages yet.\nStart a conversation!',
                style: TextStyle(color: AppColors.muted, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            );
          }

          final chats = snap.data!.docs;

          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: chats.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              color: AppColors.border,
            ),
            itemBuilder: (context, i) {
              final data = chats[i].data() as Map<String, dynamic>? ?? {};
              final participants = (data['participants'] ?? []) as List?;
              final otherUserId = participants
                  ?.firstWhere((id) => id != currentUser?.uid, orElse: () => null);

              final otherName = (data['otherUserName'] ?? 'User') as String;
              final avatar = (data['otherUserAvatar'] ?? '') as String;
              final lastMsg = (data['lastMessage'] ?? '') as String;
              final ts = data['lastMessageTime'];
              final time = _formatTimestamp(ts);

              return ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.avatarBg,
                  backgroundImage:
                      avatar.isNotEmpty ? NetworkImage(avatar) : null,
                  child: avatar.isEmpty
                      ? const Icon(Icons.person_outline,
                          color: AppColors.avatarFg)
                      : null,
                ),
                title: Text(
                  otherName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  lastMsg.isEmpty ? '(No messages yet)' : lastMsg,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 14,
                  ),
                ),
                trailing: Text(
                  time,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  if (otherUserId != null) {
                    Navigator.of(context).pushNamed('/chat', arguments: {
                      'otherUserId': otherUserId,
                    });
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  /// Formats Firestore timestamp to human-readable short string.
  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = (ts is Timestamp) ? ts.toDate() : DateTime.parse(ts.toString());
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return '';
    }
  }
}
