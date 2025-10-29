import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

class ConnectionsScreen extends StatelessWidget {
  const ConnectionsScreen({super.key});

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
          'Connections',
          style: TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('connections')
            .where('users', arrayContains: currentUid)
            .orderBy('connectedAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  "You haven’t connected with anyone yet.\nStart by chatting or booking a consultation!",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 16, height: 1.5),
                ),
              ),
            );
          }

          final connections = snap.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.border),
            itemCount: connections.length,
            itemBuilder: (context, i) {
              final data = connections[i].data() as Map<String, dynamic>;
              final users = (data['users'] ?? []) as List;
              final connectedAt = (data['connectedAt'] as Timestamp?)?.toDate();

              final otherId = users.firstWhere(
                (id) => id != currentUid,
                orElse: () => null,
              );

              if (otherId == null) return const SizedBox.shrink();

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
                      title: Text(
                        'Loading...',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    );
                  }

                  final userData =
                      userSnap.data?.data() as Map<String, dynamic>? ?? {};
                  final name = (userData['fullName'] ??
                          userData['displayName'] ??
                          userData['name'] ??
                          'User')
                      .toString();
                  final avatar = (userData['photoUrl'] ??
                          userData['profilePicture'] ??
                          '')
                      .toString();

                  String timeLabel = '';
                  if (connectedAt != null) {
                    final diff = DateTime.now().difference(connectedAt);
                    if (diff.inDays >= 1) {
                      timeLabel = '${diff.inDays}d ago';
                    } else if (diff.inHours >= 1) {
                      timeLabel = '${diff.inHours}h ago';
                    } else if (diff.inMinutes >= 1) {
                      timeLabel = '${diff.inMinutes}m ago';
                    } else {
                      timeLabel = 'Just now';
                    }
                  }

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
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      'Connected $timeLabel',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pushNamed('/profile', arguments: {
                        'userId': otherId,
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
