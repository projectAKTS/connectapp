// lib/screens/connections/connections_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/tokens.dart';
import '../profile/profile_screen.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  late final String currentUid;

  @override
  void initState() {
    super.initState();
    currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    // 🕒 Mark as seen to clear the Home badge
    if (currentUid.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .update({'lastConnectionsSeenAt': FieldValue.serverTimestamp()})
          .catchError((_) {});
    }
  }

  Future<List<QueryDocumentSnapshot>> _fetchConnections() async {
    final ref = FirebaseFirestore.instance.collection('connections');

    // Support both schemas
    final results = await Future.wait([
      ref.where('users', arrayContains: currentUid).get(),
      ref.where('userId', isEqualTo: currentUid).get(),
      ref.where('connectedUserId', isEqualTo: currentUid).get(),
    ]);

    // Merge & dedupe
    final allDocs = <String, QueryDocumentSnapshot>{};
    for (final snap in results) {
      for (final doc in snap.docs) {
        allDocs[doc.id] = doc;
      }
    }

    final docs = allDocs.values.toList()
      ..sort((a, b) {
        final aMap = a.data() as Map<String, dynamic>;
        final bMap = b.data() as Map<String, dynamic>;
        final aTs = aMap['connectedAt'] as Timestamp?;
        final bTs = bMap['connectedAt'] as Timestamp?;
        final ad = aTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = bTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
    return docs;
  }

  @override
  Widget build(BuildContext context) {
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
      body: FutureBuilder<List<QueryDocumentSnapshot>>(
        future: _fetchConnections(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.isEmpty) {
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

          final connections = snap.data!;
          return ListView.separated(
            itemCount: connections.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, i) {
              final data = connections[i].data() as Map<String, dynamic>;
              final connectedAt = (data['connectedAt'] as Timestamp?)?.toDate();

              // Determine the other user's id across schemas
              String otherId = '';
              if (data.containsKey('users')) {
                final users = List<String>.from(data['users'] ?? const []);
                otherId = users.firstWhere(
                  (id) => id != currentUid,
                  orElse: () => '',
                );
              } else {
                final u1 = data['userId'];
                final u2 = data['connectedUserId'];
                otherId = (u1 == currentUid ? (u2 ?? '') : (u1 ?? '')).toString();
              }

              if (otherId.isEmpty) {
                return const SizedBox.shrink();
              }

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(otherId).get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) {
                    return const ListTile(
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.avatarBg,
                        child: Icon(Icons.person_outline, color: AppColors.avatarFg),
                      ),
                      title: Text('Loading...', style: TextStyle(color: AppColors.muted)),
                    );
                  }

                  final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
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
                      backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                      child: avatar.isEmpty
                          ? const Icon(Icons.person_outline, color: AppColors.avatarFg)
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
                      // ✅ Push profile screen directly with a non-null String
                      final String oid = otherId; // guaranteed non-empty here
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(userID: oid),
                        ),
                      );
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
