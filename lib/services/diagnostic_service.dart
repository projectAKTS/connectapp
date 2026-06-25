import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import 'helperly_test_runtime.dart';

class DiagnosticService {
  DiagnosticService._();

  static const Duration _writeTimeout = Duration(seconds: 3);

  static FirebaseFirestore get _db => HelperlyTestRuntime.firestore;

  static String? _resolveUid([String? uid]) {
    final explicit = uid?.trim() ?? '';
    if (explicit.isNotEmpty) return explicit;
    final runtimeUid = HelperlyTestRuntime.currentUid?.trim() ?? '';
    if (runtimeUid.isNotEmpty) return runtimeUid;
    final authUid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    return authUid.isEmpty ? null : authUid;
  }

  static String _truncateMeta(Object? meta) {
    final text = meta == null ? '' : meta.toString();
    return text.length > 500 ? text.substring(0, 500) : text;
  }

  static Map<String, dynamic> _counterFields(Map<String, int>? counters) {
    if (counters == null || counters.isEmpty) return const <String, dynamic>{};
    return <String, dynamic>{
      'activeListeners': counters['activeListeners'] ?? 0,
      'activeTimers': counters['activeTimers'] ?? 0,
      'activeCallSubscriptions': counters['activeCallSubscriptions'] ?? 0,
      'activeChatSubscriptions': counters['activeChatSubscriptions'] ?? 0,
    };
  }

  static Map<String, dynamic> _diagFields(Map<String, dynamic> fields) {
    return <String, dynamic>{
      'diag': fields,
    };
  }

  static void _write(String? uid, Map<String, dynamic> fields) {
    final resolvedUid = _resolveUid(uid);
    if (resolvedUid == null) return;
    unawaited(_writeAsync(resolvedUid, fields));
  }

  static Future<void> _writeAsync(
    String uid,
    Map<String, dynamic> fields,
  ) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .set(fields, SetOptions(merge: true))
          .timeout(_writeTimeout);
    } catch (_) {}
  }

  static void logCall(
    String stage, {
    Object? meta,
    String? uid,
    Map<String, int>? counters,
  }) {
    _write(
        uid,
        _diagFields(<String, dynamic>{
          'lastCallStage': stage,
          'lastCallMeta': _truncateMeta(meta),
          'lastCallAt': FieldValue.serverTimestamp(),
          ..._counterFields(counters),
        }));
  }

  static void logPush(
    String stage, {
    Object? meta,
    String? uid,
    Map<String, int>? counters,
  }) {
    _write(
        uid,
        _diagFields(<String, dynamic>{
          'lastPushStage': stage,
          'lastPushMeta': _truncateMeta(meta),
          'lastPushAt': FieldValue.serverTimestamp(),
          ..._counterFields(counters),
        }));
  }

  static void logChat(
    String stage, {
    Object? meta,
    String? uid,
    Map<String, int>? counters,
  }) {
    _write(
        uid,
        _diagFields(<String, dynamic>{
          'lastChatStage': stage,
          'lastChatMeta': _truncateMeta(meta),
          'lastChatAt': FieldValue.serverTimestamp(),
          ..._counterFields(counters),
        }));
  }

  static void logLifecycle(
    AppLifecycleState state, {
    String? uid,
    Map<String, int>? counters,
  }) {
    _write(
        uid,
        _diagFields(<String, dynamic>{
          'lastLifecycleState': 'app_${state.name}',
          'lifecycleAt': FieldValue.serverTimestamp(),
          ..._counterFields(counters),
        }));
  }

  static void logSystem(
    String stage, {
    Object? meta,
    String? uid,
    Map<String, int>? counters,
  }) {
    _write(
        uid,
        _diagFields(<String, dynamic>{
          'lastSystemStage': stage,
          'lastSystemMeta': _truncateMeta(meta),
          'lastSystemAt': FieldValue.serverTimestamp(),
          ..._counterFields(counters),
        }));
  }

  static void updateCounters(
    Map<String, int> counters, {
    String? uid,
  }) {
    _write(uid, _diagFields(_counterFields(counters)));
  }
}
