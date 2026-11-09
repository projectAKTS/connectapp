import 'package:connect_app/utils/time_utils.dart';
import 'package:connect_app/l10n/formatters.dart';
import 'package:connect_app/widgets/initials_avatar.dart';
import 'package:connect_app/l10n/l10n.dart';
import 'dart:async';

import 'package:connect_app/services/safety_service.dart';
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
    return context.l10n.commonUser;
  }

  /// Attachments and missed calls are labelled from `lastMessageType` in
  /// the reader's language; `lastMessageText` for them is English text
  /// written by the server or older builds.
  String _previewFromChatData(Map<String, dynamic> chatData) {
    final l = context.l10n;
    final type = (chatData['lastMessageType'] ?? '').toString().trim();
    if (type == 'image') return l.messagePhoto;
    if (type == 'video') return l.messageVideo;
    if (type == 'file') return l.messageFile;
    if (type == 'missed_call') return l.messageMissedCall;
    final text = (chatData['lastMessageText'] ?? '').toString().trim();
    if (text.isNotEmpty) return text;
    return l.messagesOpenToView;
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
          return Center(
            child: Text(
              context.l10n.messagesEmpty,
              style: const TextStyle(color: AppColors.muted, fontSize: 16),
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
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.avatarBg,
                      child:
                          Icon(Icons.person_outline, color: AppColors.avatarFg),
                    ),
                    title: Text(
                      context.l10n.commonLoading,
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
                    context.l10n.messagesOpenToView,
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
    SafetyService.instance.watch();
    SafetyService.instance.blocked.addListener(_onBlockedChanged);
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
      // Each chat stays unread until it is opened, as in messaging apps.
    }
  }

  @override
  void dispose() {
    SafetyService.instance.blocked.removeListener(_onBlockedChanged);
    _waitingGuard?.cancel();
    super.dispose();
  }

  void _onBlockedChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final authUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final requestedUid = (widget.userId ?? '').trim();
    final currentUid = (requestedUid.isNotEmpty && requestedUid == authUid)
        ? requestedUid
        : authUid;
    if (currentUid.isEmpty) {
      return FullScreenBackGesture(
        child: Scaffold(
          body: Center(
            child: Text(
              context.l10n.messagesLoginAgain,
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
          backgroundColor: AppColors.canvas,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: AppColors.text),
          title: Text(
            context.l10n.messagesTitle,
            style: const TextStyle(
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
                  if (SafetyService.instance.isBlocked(otherId)) continue;

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
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.avatarBg,
                              child: Icon(Icons.person_outline,
                                  color: AppColors.avatarFg),
                            ),
                            title: Text(
                              context.l10n.commonLoading,
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

                        final unreadMap = chatData['unreadBy'];
                        final unread = unreadMap is Map
                            ? ((unreadMap[currentUid] as num?)?.toInt() ?? 0)
                            : 0;
                        final lastAt = parseFirestoreTimestamp(
                            chatData['lastMessageAt'] ?? chatData['updatedAt']);
                        return ListTile(
                          leading: InitialsAvatar(
                              url: avatar, name: otherName, radius: 24),
                          title: Text(
                            otherName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight:
                                  unread > 0 ? FontWeight.w700 : FontWeight.w600,
                              color: AppColors.text,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color:
                                  unread > 0 ? AppColors.text : AppColors.muted,
                              fontWeight:
                                  unread > 0 ? FontWeight.w600 : FontWeight.w400,
                              fontSize: 14,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (lastAt != null)
                                Text(
                                  AppFormat.timeAgo(context, lastAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: unread > 0
                                        ? AppColors.primary
                                        : AppColors.muted,
                                  ),
                                ),
                              if (unread > 0) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    unread > 99 ? '99+' : '$unread',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
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
