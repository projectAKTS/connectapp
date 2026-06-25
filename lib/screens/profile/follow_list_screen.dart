import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:connect_app/theme/tokens.dart';
import 'package:connect_app/widgets/full_screen_back_gesture.dart';
import 'package:connect_app/screens/profile/profile_screen.dart';
import 'package:connect_app/services/firestore_read_helper.dart';

enum FollowListType { followers, following }

class FollowListScreen extends StatefulWidget {
  final FollowListType type;
  final String? userId;
  const FollowListScreen({super.key, required this.type, this.userId});

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  late final String _uid;
  late Future<List<String>> _idsFuture;

  @override
  void initState() {
    super.initState();
    _uid = widget.userId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    _idsFuture = _loadIds();
  }

  Future<List<String>> _loadIds() async {
    if (_uid.isEmpty) return const <String>[];
    if (widget.type == FollowListType.followers) {
      final snap = await FirestoreReadHelper.getQuery(
        FirebaseFirestore.instance
            .collection('followers')
            .doc(_uid)
            .collection('userFollowers'),
      );
      return snap.docs
          .map((d) => d.id)
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
    }

    final snap = await FirestoreReadHelper.getDoc(
      FirebaseFirestore.instance.collection('users').doc(_uid),
    );
    final data = snap.data() ?? const <String, dynamic>{};
    return (data['following'] is List)
        ? (data['following'] as List)
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty && e != _uid)
            .toSet()
            .toList()
        : <String>[];
  }

  Future<void> _refresh() async {
    setState(() {
      _idsFuture = _loadIds();
    });
    await _idsFuture;
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.type == FollowListType.followers ? 'Followers' : 'Following';

    if (_uid.isEmpty) {
      return FullScreenBackGesture(
        child: Scaffold(
          backgroundColor: AppColors.canvas,
          appBar: AppBar(title: Text(title)),
          body: const Center(
            child: Text(
              'Please sign in again.',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ),
      );
    }

    return FullScreenBackGesture(
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(title: Text(title)),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<String>>(
            future: _idsFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final ids = snap.data ?? const <String>[];
              return _buildList(
                ids,
                emptyText: widget.type == FollowListType.followers
                    ? 'No followers yet.'
                    : 'Not following anyone yet.',
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<String> ids, {required String emptyText}) {
    if (ids.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(
            child: Text(
              emptyText,
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: ids.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.border),
      itemBuilder: (context, i) => _FollowUserRow(userId: ids[i]),
    );
  }
}

class _FollowUserRow extends StatelessWidget {
  final String userId;
  const _FollowUserRow({required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirestoreReadHelper.getDoc(
        FirebaseFirestore.instance.collection('users').doc(userId),
      ),
      builder: (context, snap) {
        final data = snap.data?.data() ?? const <String, dynamic>{};
        final name =
            (data['displayName'] ?? data['fullName'] ?? data['name'] ?? 'User')
                .toString();
        final avatar =
            (data['profilePicture'] ?? data['photoUrl'] ?? '').toString();

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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          onTap: () {
            Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => ProfileScreen(userID: userId)),
            );
          },
        );
      },
    );
  }
}
