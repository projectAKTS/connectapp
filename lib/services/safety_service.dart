import 'dart:async';

import 'package:connect_app/l10n/l10n.dart';
import 'package:connect_app/l10n/value_labels.dart';
import 'package:connect_app/services/app_telemetry.dart';
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

  /// Stored as-is in `reports.reason` for moderators; shown translated.
  static const List<String> reportReasons = [
    'Spam or scam',
    'Harassment or hate',
    'Inappropriate content',
    'Harmful or misleading advice',
    'Pretending to be someone else',
    'Inappropriate behaviour during a call',
    'Something else',
  ];

  final ValueNotifier<Set<String>> blocked = ValueNotifier(const <String>{});

  /// Posts this user reported: hidden from them at once. Kept in
  /// `users/{uid}/private/safety`, which only they can read, so reports stay
  /// private.
  final ValueNotifier<Set<String>> hiddenPosts =
      ValueNotifier(const <String>{});
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _privateSub;
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
    unawaited(_privateSub?.cancel());
    _privateSub = _safetyDoc(uid).snapshots().listen((snap) {
      final hidden = snap.data()?['hiddenPostIds'];
      hiddenPosts.value = hidden is List
          ? hidden.map((e) => '$e').where((e) => e.isNotEmpty).toSet()
          : const <String>{};
    }, onError: (_) {});
  }

  void stop() {
    unawaited(_sub?.cancel());
    _sub = null;
    unawaited(_privateSub?.cancel());
    _privateSub = null;
    _watchedUid = null;
    blocked.value = const <String>{};
    hiddenPosts.value = const <String>{};
  }

  DocumentReference<Map<String, dynamic>> _safetyDoc(String uid) =>
      HelperlyTestRuntime.firestore
          .collection('users')
          .doc(uid)
          .collection('private')
          .doc('safety');

  bool isBlocked(String uid) => uid.isNotEmpty && blocked.value.contains(uid);

  /// Whether a post stays out of feeds: this user reported it, enough people
  /// did (`hiddenByReports`), or the photo check found it very likely adult
  /// or violent (`hiddenBySafety`); the server keeps the last two until
  /// review.
  bool hidesPost(String postId, Map<String, dynamic> data) =>
      hiddenPosts.value.contains(postId) ||
      data['hiddenByReports'] == true ||
      data['hiddenBySafety'] == true;

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
    if (type == 'post' && targetId.isNotEmpty) {
      hiddenPosts.value = {...hiddenPosts.value, targetId};
      await _safetyDoc(uid).set({
        'hiddenPostIds': FieldValue.arrayUnion([targetId]),
      }, SetOptions(merge: true));
    }
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
    final l10n = context.l10n;
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.canvas,
      showDragHandle: true,
      // Scrolls on small screens; French reasons are longer.
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                l10n.reportSheetTitle,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                l10n.reportSheetSubtitle,
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
            for (final r in reportReasons)
              ListTile(
                title: Text(ValueLabels.reportReason(l10n, r)),
                onTap: () => Navigator.pop(ctx, r),
              ),
            const SizedBox(height: 8),
          ],
        )),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.reportFailed),
        ));
      }
      return false;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.reportSent),
      ));
      AppTelemetry.event('report_submitted', {'type': type});
    }
    return true;
  }

  /// Confirms, then blocks. Returns true when blocked.
  Future<bool> blockWithConfirm(
    BuildContext context, {
    required String targetUid,
    required String name,
  }) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.blockTitle(name)),
        content: Text(l10n.blockBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.blockAction,
                style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    await setBlocked(targetUid, true);
    AppTelemetry.event('user_blocked');
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.blockDone(name))));
    }
    return true;
  }
}
