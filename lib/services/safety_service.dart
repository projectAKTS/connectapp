import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:connect_app/theme/tokens.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Report and block, required by the App Store and Google Play for apps with
/// user-generated content.
///
/// Reports go to `/reports` for moderation. Blocked uids live on the
/// blocker's own user doc (`blockedUids`), which only the owner can write;
/// screens filter blocked people out of the feed, helper lists and chats.
class SafetyService {
  SafetyService._();

  static final SafetyService instance = SafetyService._();

  static const List<String> reportReasons = [
    'Spam or scam',
    'Harassment or hate',
    'Inappropriate content',
    'Harmful or misleading advice',
    'Pretending to be someone else',
    'Something else',
  ];

  final ValueNotifier<Set<String>> blocked = ValueNotifier(const <String>{});
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  String? _watchedUid;

  /// Keeps [blocked] in sync with the signed-in user's doc.
  void watch() {
    final uid = HelperlyTestRuntime.currentUid ?? '';
    if (uid.isEmpty || uid == _watchedUid) return;
    unawaited(_sub?.cancel());
    _watchedUid = uid;
    _sub = HelperlyTestRuntime.firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      final raw = snap.data()?['blockedUids'];
      blocked.value = raw is List
          ? raw.map((e) => '$e').where((e) => e.isNotEmpty).toSet()
          : const <String>{};
    }, onError: (_) {});
  }

  void stop() {
    unawaited(_sub?.cancel());
    _sub = null;
    _watchedUid = null;
    blocked.value = const <String>{};
  }

  bool isBlocked(String uid) => uid.isNotEmpty && blocked.value.contains(uid);

  Future<void> report({
    required String type,
    required String targetId,
    String targetUid = '',
    required String reason,
  }) async {
    final uid = HelperlyTestRuntime.currentUid ?? '';
    if (uid.isEmpty) return;
    await HelperlyTestRuntime.firestore.collection('reports').add({
      'type': type,
      'targetId': targetId,
      'targetUid': targetUid,
      'reason': reason,
      'reporterUid': uid,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setBlocked(String targetUid, bool block) async {
    final uid = HelperlyTestRuntime.currentUid ?? '';
    if (uid.isEmpty || targetUid.isEmpty || targetUid == uid) return;
    final next = Set<String>.of(blocked.value);
    block ? next.add(targetUid) : next.remove(targetUid);
    blocked.value = next;
    await HelperlyTestRuntime.firestore.collection('users').doc(uid).set({
      'blockedUids': block
          ? FieldValue.arrayUnion([targetUid])
          : FieldValue.arrayRemove([targetUid]),
    }, SetOptions(merge: true));
  }

  /// Asks for a reason and files the report. Returns true when sent.
  Future<bool> reportWithSheet(
    BuildContext context, {
    required String type,
    required String targetId,
    String targetUid = '',
  }) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.canvas,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                'Why are you reporting this?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Reports are private. Our team reviews them.',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
            for (final r in reportReasons)
              ListTile(
                title: Text(r),
                onTap: () => Navigator.pop(ctx, r),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (reason == null) return false;
    try {
      await report(
        type: type,
        targetId: targetId,
        targetUid: targetUid,
        reason: reason,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not send the report. Please try again.'),
        ));
      }
      return false;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Thanks. We received your report.'),
      ));
    }
    return true;
  }

  /// Confirms, then blocks. Returns true when blocked.
  Future<bool> blockWithConfirm(
    BuildContext context, {
    required String targetUid,
    required String name,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Block $name?'),
        content: const Text(
          "You won't see their posts or messages, and they won't appear in "
          'your helper list. You can unblock them from their profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Block', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    await setBlocked(targetUid, true);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$name is blocked.')));
    }
    return true;
  }
}
