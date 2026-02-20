import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connect_app/theme/tokens.dart';
import 'package:connect_app/widgets/full_screen_back_gesture.dart';

class MessagesScreen extends StatefulWidget {
  final String? userId;
  const MessagesScreen({super.key, this.userId});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  @override
  void initState() {
    super.initState();
    final uid = widget.userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isNotEmpty) {
      FirebaseFirestore.instance.collection('users').doc(uid).set(
        {'lastMessagesSeenAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      ).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid =
        widget.userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    final rootNav = Navigator.of(context, rootNavigator: true);

    return FullScreenBackGesture(
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          backgroundColor: AppColors.card,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: AppColors.text),
          title: const Text(
            'Messages',
            style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
                fontSize: 18),
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('connections')
              .where('users', arrayContains: currentUid)
              .snapshots(),
          builder: (context, usersConnSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('connections')
                  .where('userId', isEqualTo: currentUid)
                  .snapshots(),
              builder: (context, userIdConnSnap) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('connections')
                      .where('connectedUserId', isEqualTo: currentUid)
                      .snapshots(),
                  builder: (context, connectedUserIdConnSnap) {
                    if (usersConnSnap.connectionState ==
                            ConnectionState.waiting &&
                        userIdConnSnap.connectionState ==
                            ConnectionState.waiting &&
                        connectedUserIdConnSnap.connectionState ==
                            ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final merged = <String, Map<String, dynamic>>{};
                    for (final s in [
                      usersConnSnap,
                      userIdConnSnap,
                      connectedUserIdConnSnap
                    ]) {
                      if (!s.hasData) continue;
                      for (final d in s.data!.docs) {
                        merged[d.id] = (d.data() as Map<String, dynamic>? ??
                            const <String, dynamic>{});
                      }
                    }

                    final rows = <Map<String, dynamic>>[];
                    for (final entry in merged.entries) {
                      final data = entry.value;
                      String otherId = '';
                      if (data['users'] is List) {
                        final users = (data['users'] as List)
                            .map((e) => e.toString())
                            .toList();
                        otherId = users.firstWhere(
                          (id) => id != currentUid,
                          orElse: () => '',
                        );
                      }
                      if (otherId.isEmpty) {
                        final u1 = (data['userId'] ?? '').toString();
                        final u2 = (data['connectedUserId'] ?? '').toString();
                        if (u1 == currentUid && u2.isNotEmpty) otherId = u2;
                        if (u2 == currentUid && u1.isNotEmpty) otherId = u1;
                      }
                      if (otherId.isEmpty) continue;
                      final chatIds = [currentUid, otherId]..sort();
                      rows.add({
                        'otherId': otherId,
                        'chatId': chatIds.join('_'),
                        'connectedAt': data['connectedAt'],
                      });
                    }

                    rows.sort((a, b) {
                      final at = (a['connectedAt'] as Timestamp?)?.toDate() ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      final bt = (b['connectedAt'] as Timestamp?)?.toDate() ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      return bt.compareTo(at);
                    });

                    if (rows.isEmpty) {
                      return const Center(
                        child: Text(
                          'No conversations yet.',
                          style:
                              TextStyle(color: AppColors.muted, fontSize: 16),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, i) {
                        final otherId = rows[i]['otherId'].toString();
                        final chatId = rows[i]['chatId'].toString();

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

                            final userData = userSnap.data?.data()
                                    as Map<String, dynamic>? ??
                                {};
                            final otherName = (userData['name'] ??
                                    userData['displayName'] ??
                                    userData['fullName'] ??
                                    'User')
                                .toString();
                            final avatar = (userData['avatar'] ??
                                    userData['photoUrl'] ??
                                    userData['photoURL'] ??
                                    userData['profilePicture'] ??
                                    userData['userAvatar'] ??
                                    '')
                                .toString();

                            return ListTile(
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundColor: AppColors.avatarBg,
                                backgroundImage: avatar.isNotEmpty
                                    ? NetworkImage(avatar)
                                    : null,
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
                                  if (!msgSnap.hasData ||
                                      msgSnap.data!.docs.isEmpty) {
                                    return const Text('(No messages yet)',
                                        style:
                                            TextStyle(color: AppColors.muted));
                                  }
                                  final last = msgSnap.data!.docs.first.data()
                                      as Map<String, dynamic>;
                                  final type = (last['type'] ?? '').toString();
                                  final text = (last['text'] ?? '').toString();
                                  final preview = text.isNotEmpty
                                      ? text
                                      : (type == 'image'
                                          ? 'Photo'
                                          : type == 'video'
                                              ? 'Video'
                                              : '(Attachment)');
                                  return Text(
                                    preview,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppColors.muted, fontSize: 14),
                                  );
                                },
                              ),
                              onTap: () {
                                debugPrint(
                                    '[Messages] open chat tap otherId=$otherId otherName=$otherName chatId=$chatId');
                                rootNav.pushNamed('/chat', arguments: {
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
                );
              },
            );
          },
        ),
      ),
    );
  }
}
