import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connect_app/theme/tokens.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.text),
        title: const Text(
          'Messages',
          style: TextStyle(
              color: AppColors.text, fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No conversations yet.',
                style: TextStyle(color: AppColors.muted, fontSize: 16),
              ),
            );
          }

          final chats = snap.data!.docs;

          return ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, i) {
              final data = chats[i].data() as Map<String, dynamic>;
              final participants = (data['participants'] ?? []) as List;
              final otherId = participants
                  .firstWhere((id) => id != currentUid, orElse: () => null);
              final chatId = chats[i].id;

              if (otherId == null) {
                return const SizedBox.shrink();
              }

              // Fetch other user's profile from /users/{uid}
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(otherId)
                    .get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) {
                    return const ListTile(
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.avatarBg,
                        child: Icon(Icons.person_outline,
                            color: AppColors.avatarFg),
                      ),
                      title: Text('Loading...',
                          style: TextStyle(color: AppColors.muted)),
                    );
                  }

                  final userData =
                      userSnap.data?.data() as Map<String, dynamic>? ?? {};
                  final otherName =
                      (userData['name'] ?? userData['displayName'] ?? 'User')
                          .toString();
                  final avatar =
                      (userData['avatar'] ?? userData['photoUrl'] ?? '')
                          .toString();

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
                    subtitle: FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('chats')
                          .doc(chatId)
                          .collection('messages')
                          .orderBy('createdAt', descending: true)
                          .limit(1)
                          .get(),
                      builder: (context, msgSnap) {
                        if (!msgSnap.hasData || msgSnap.data!.docs.isEmpty) {
                          return const Text('(No messages yet)',
                              style: TextStyle(color: AppColors.muted));
                        }
                        final last = msgSnap.data!.docs.first.data()
                            as Map<String, dynamic>;
                        return Text(
                          last['text'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 14),
                        );
                      },
                    ),
                    onTap: () {
                      Navigator.of(context).pushNamed('/chat', arguments: {
                        'chatId': chatId,
                        'otherUserId': otherId,
                        'otherUserName': otherName,
                        'otherUserAvatar': avatar,
                      });
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
