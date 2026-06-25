import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connect_app/theme/tokens.dart';
import 'package:connect_app/services/firestore_read_helper.dart';
import 'package:connect_app/widgets/full_screen_back_gesture.dart';

class MessagesScreen extends StatefulWidget {
  final String? userId;
  const MessagesScreen({super.key, this.userId});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  Timer? _waitingGuard;
  bool _allowWaitingFallback = false;
  final Map<String, Future<DocumentSnapshot<Map<String, dynamic>>>>
      _userDocFutureCache = {};
  final Map<String, Future<List<Map<String, String>>>>
      _connectionRowsFutureCache = {};

  Future<DocumentSnapshot<Map<String, dynamic>>> _userDocFuture(String userId) {
    final cached = _userDocFutureCache[userId];
    if (cached != null) return cached;
    late final Future<DocumentSnapshot<Map<String, dynamic>>> future;
    future = FirestoreReadHelper.getDoc(
      FirebaseFirestore.instance.collection('users').doc(userId),
    ).catchError((Object error, StackTrace stackTrace) {
      if (identical(_userDocFutureCache[userId], future)) {
        _userDocFutureCache.remove(userId);
      }
      Error.throwWithStackTrace(error, stackTrace);
    });
    _userDocFutureCache[userId] = future;
    return future;
  }

  Future<List<Map<String, String>>> _loadConnectionRows(
      String currentUid) async {
    final connections = FirebaseFirestore.instance.collection('connections');
    final snaps = <QuerySnapshot<Map<String, dynamic>>>[];
    try {
      snaps.add(await FirestoreReadHelper.getQuery(
        connections.where('users', arrayContains: currentUid),
      ));
    } catch (_) {}
    try {
      snaps.add(await FirestoreReadHelper.getQuery(
        connections.where('userId', isEqualTo: currentUid),
      ));
    } catch (_) {}
    try {
      snaps.add(await FirestoreReadHelper.getQuery(
        connections.where('connectedUserId', isEqualTo: currentUid),
      ));
    } catch (_) {}

    final merged = <String, Map<String, dynamic>>{};
    for (final snap in snaps) {
      for (final doc in snap.docs) {
        merged[doc.id] = doc.data();
      }
    }

    final rowsByOther = <String, Map<String, String>>{};
    for (final data in merged.values) {
      final users = ((data['users'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
      String otherId = users.firstWhere(
        (id) => id != currentUid,
        orElse: () => '',
      );
      if (otherId.isEmpty) {
        final u1 = (data['userId'] ?? '').toString();
        final u2 = (data['connectedUserId'] ?? '').toString();
        if (u1 == currentUid && u2.isNotEmpty) otherId = u2;
        if (u2 == currentUid && u1.isNotEmpty) otherId = u1;
      }
      if (otherId.isEmpty || otherId == currentUid) continue;
      final ids = [currentUid, otherId]..sort();
      rowsByOther[otherId] = {
        'otherId': otherId,
        'chatId': ids.join('_'),
      };
    }

    return rowsByOther.values.toList(growable: false);
  }

  Future<List<Map<String, String>>> _connectionRowsFuture(String currentUid) {
    return _connectionRowsFutureCache.putIfAbsent(
      currentUid,
      () => _loadConnectionRows(currentUid),
    );
  }

  String _otherIdFromChatId(String chatId, String currentUid) {
    final id = chatId.trim();
    final me = currentUid.trim();
    if (id.isEmpty || me.isEmpty) return '';

    final prefix = '${me}_';
    if (id.startsWith(prefix) && id.length > prefix.length) {
      return id.substring(prefix.length);
    }
    final suffix = '_$me';
    if (id.endsWith(suffix) && id.length > suffix.length) {
      return id.substring(0, id.length - suffix.length);
    }

    final parts = id.split('_');
    if (parts.length == 2) {
      return parts.first == me ? parts.last : parts.first;
    }
    return '';
  }

  bool _looksLikeUid(String value) {
    final v = value.trim();
    if (v.length < 16) return false;
    if (v.contains(' ')) return false;
    return RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(v);
  }

  String _displayNameFromUserData(Map<String, dynamic> userData) {
    final candidates = <String>[
      (userData['displayName'] ?? '').toString().trim(),
      (userData['fullName'] ?? '').toString().trim(),
      (userData['name'] ?? '').toString().trim(),
      (userData['userName'] ?? '').toString().trim(),
    ];
    for (final candidate in candidates) {
      if (candidate.isEmpty) continue;
      if (_looksLikeUid(candidate)) continue;
      return candidate;
    }
    return 'User';
  }

  String _previewFromChatData(Map<String, dynamic> chatData) {
    final text = (chatData['lastMessageText'] ?? '').toString().trim();
    if (text.isNotEmpty) return text;
    final type = (chatData['lastMessageType'] ?? '').toString().trim();
    if (type == 'image') return 'Photo';
    if (type == 'video') return 'Video';
    if (type == 'file') return 'File';
    if (type == 'missed_call') return 'Missed call';
    return '(Open to view messages)';
  }

  Widget _buildConnectionsFallback({
    required String currentUid,
    required NavigatorState rootNav,
  }) {
    return FutureBuilder<List<Map<String, String>>>(
      future: _connectionRowsFuture(currentUid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final rows = snap.data ?? const <Map<String, String>>[];
        if (rows.isEmpty) {
          return const Center(
            child: Text(
              'No conversations yet.',
              style: TextStyle(color: AppColors.muted, fontSize: 16),
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
            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: _userDocFuture(otherId),
              builder: (context, userSnap) {
                if (userSnap.connectionState == ConnectionState.waiting &&
                    !userSnap.hasData) {
                  return const ListTile(
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.avatarBg,
                      child:
                          Icon(Icons.person_outline, color: AppColors.avatarFg),
                    ),
                    title: Text(
                      'Loading...',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }
                final userData =
                    userSnap.data?.data() ?? const <String, dynamic>{};
                final otherName = _displayNameFromUserData(userData);
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
                  subtitle: const Text(
                    '(Open to view messages)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                    ),
                  ),
                  onTap: () {
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
  }

  @override
  void initState() {
    super.initState();
    _waitingGuard = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      setState(() => _allowWaitingFallback = true);
    });
    final authUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final requestedUid = (widget.userId ?? '').trim();
    final uid = (requestedUid.isNotEmpty && requestedUid == authUid)
        ? requestedUid
        : authUid;
    if (uid.isNotEmpty) {
      FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'lastMessagesSeenAt': FieldValue.serverTimestamp(),
          'unreadMessagesCount': 0,
        },
        SetOptions(merge: true),
      ).catchError((_) {});
      _markAllChatsRead(uid);
    }
  }

  @override
  void dispose() {
    _waitingGuard?.cancel();
    super.dispose();
  }

  Future<void> _markAllChatsRead(String uid) async {
    try {
      final chats = FirebaseFirestore.instance.collection('chats');
      final snaps = <QuerySnapshot<Map<String, dynamic>>>[];
      try {
        snaps.add(await FirestoreReadHelper.getQuery(
          chats.where('participants', arrayContains: uid),
        ));
      } catch (_) {}
      try {
        snaps.add(await FirestoreReadHelper.getQuery(
          chats.where('users', arrayContains: uid),
        ));
      } catch (_) {}
      final docsById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final snap in snaps) {
        for (final doc in snap.docs) {
          docsById[doc.id] = doc;
        }
      }
      for (final doc in docsById.values) {
        final unreadBy = doc.data()['unreadBy'];
        final unreadCount =
            unreadBy is Map ? ((unreadBy[uid] as num?)?.toInt() ?? 0) : 0;
        if (unreadCount <= 0) continue;
        final ref = doc.reference;
        await ref.set({'unreadBy.$uid': 0}, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final authUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final requestedUid = (widget.userId ?? '').trim();
    final currentUid = (requestedUid.isNotEmpty && requestedUid == authUid)
        ? requestedUid
        : authUid;
    if (currentUid.isEmpty) {
      return const FullScreenBackGesture(
        child: Scaffold(
          body: Center(
            child: Text(
              'Please log in again.',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ),
      );
    }
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
              .collection('chats')
              .where('participants', arrayContains: currentUid)
              .snapshots(),
          builder: (context, participantsSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('users', arrayContains: currentUid)
                  .snapshots(),
              builder: (context, usersSnap) {
                final waiting = participantsSnap.connectionState ==
                        ConnectionState.waiting &&
                    usersSnap.connectionState == ConnectionState.waiting;
                if (waiting) {
                  if (_allowWaitingFallback) {
                    return _buildConnectionsFallback(
                      currentUid: currentUid,
                      rootNav: rootNav,
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                }
                final hasAnyData =
                    participantsSnap.hasData || usersSnap.hasData;
                if (!hasAnyData &&
                    (participantsSnap.hasError || usersSnap.hasError)) {
                  return _buildConnectionsFallback(
                    currentUid: currentUid,
                    rootNav: rootNav,
                  );
                }

                final merged = <String, Map<String, dynamic>>{};
                if (participantsSnap.hasData) {
                  for (final d in participantsSnap.data!.docs) {
                    merged[d.id] = (d.data() as Map<String, dynamic>? ??
                        const <String, dynamic>{});
                  }
                }
                if (usersSnap.hasData) {
                  for (final d in usersSnap.data!.docs) {
                    merged[d.id] = (d.data() as Map<String, dynamic>? ??
                        const <String, dynamic>{});
                  }
                }

                final rowsByChatId = <String, Map<String, dynamic>>{};
                for (final entry in merged.entries) {
                  final chatId = entry.key;
                  final data = entry.value;
                  final users = <String>[
                    ...((data['users'] as List?) ?? const [])
                        .map((e) => e.toString()),
                    ...((data['participants'] as List?) ?? const [])
                        .map((e) => e.toString()),
                  ].where((e) => e.isNotEmpty).toSet().toList();

                  String otherId = users.firstWhere(
                    (id) => id != currentUid,
                    orElse: () => '',
                  );
                  if (otherId.isEmpty && chatId.contains('_')) {
                    otherId = _otherIdFromChatId(chatId, currentUid);
                  }
                  if (otherId.isEmpty || otherId == currentUid) continue;

                  rowsByChatId[chatId] = {
                    'otherId': otherId,
                    'chatId': chatId,
                    'updatedAt': data['updatedAt'] ?? data['lastMessageAt'],
                    'chat': data,
                  };
                }

                final rows = rowsByChatId.values.toList()
                  ..sort((a, b) {
                    final at = (a['updatedAt'] as Timestamp?)?.toDate() ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    final bt = (b['updatedAt'] as Timestamp?)?.toDate() ??
                        DateTime.fromMillisecondsSinceEpoch(0);
                    return bt.compareTo(at);
                  });

                if (rows.isEmpty) {
                  return _buildConnectionsFallback(
                    currentUid: currentUid,
                    rootNav: rootNav,
                  );
                }

                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, i) {
                    final otherId = rows[i]['otherId'].toString();
                    final chatId = rows[i]['chatId'].toString();
                    final chatData =
                        (rows[i]['chat'] as Map<String, dynamic>? ??
                            const <String, dynamic>{});
                    final preview = _previewFromChatData(chatData);

                    return FutureBuilder<
                        DocumentSnapshot<Map<String, dynamic>>>(
                      future: _userDocFuture(otherId),
                      builder: (context, userSnap) {
                        if (userSnap.connectionState ==
                            ConnectionState.waiting) {
                          return const ListTile(
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.avatarBg,
                              child: Icon(Icons.person_outline,
                                  color: AppColors.avatarFg),
                            ),
                            title: Text(
                              'Loading...',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }
                        final userData =
                            userSnap.data?.data() ?? const <String, dynamic>{};
                        final otherName = _displayNameFromUserData(userData);
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
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 14,
                            ),
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
        ),
      ),
    );
  }
}
