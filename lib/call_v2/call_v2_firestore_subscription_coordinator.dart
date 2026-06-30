import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'call_v2_api.dart';
import 'call_v2_feature_gate.dart';
import 'call_v2_firestore_snapshot_adapter.dart';
import 'call_v2_harness.dart';

typedef CallV2CallDocumentStreamFactory
    = Stream<DocumentSnapshot<Map<String, dynamic>>> Function(String callId);

typedef CallV2ParticipantDocumentStreamFactory
    = Stream<DocumentSnapshot<Map<String, dynamic>>> Function(
  String callId,
  String participantUid,
);

enum CallV2SubscriptionStatus {
  idle,
  listening,
  stopped,
  failed,
}

class CallV2FirestoreSubscriptionCoordinator {
  CallV2FirestoreSubscriptionCoordinator({
    required CallV2FeatureGate featureGate,
    required CallV2Harness harness,
    required CallV2FirestoreSnapshotAdapter adapter,
    required CallV2CallDocumentStreamFactory callDocumentStream,
    required CallV2ParticipantDocumentStreamFactory participantDocumentStream,
  })  : _featureGate = featureGate,
        _harness = harness,
        _adapter = adapter,
        _callDocumentStream = callDocumentStream,
        _participantDocumentStream = participantDocumentStream;

  final CallV2FeatureGate _featureGate;
  final CallV2Harness _harness;
  final CallV2FirestoreSnapshotAdapter _adapter;
  final CallV2CallDocumentStreamFactory _callDocumentStream;
  final CallV2ParticipantDocumentStreamFactory _participantDocumentStream;

  final List<StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
      _subscriptions =
      <StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>[];

  int _generation = 0;
  CallV2SubscriptionStatus _status = CallV2SubscriptionStatus.idle;
  CallV2ClientErrorCode? _lastErrorCode;
  _SubscriptionIdentity? _identity;
  DocumentSnapshot<Map<String, dynamic>>? _latestCallDocument;
  DocumentSnapshot<Map<String, dynamic>>? _latestCallerDocument;
  DocumentSnapshot<Map<String, dynamic>>? _latestCalleeDocument;

  bool get isRunning => _status == CallV2SubscriptionStatus.listening;

  String? get activeCallId => _identity?.callId;

  CallV2SubscriptionStatus get status => _status;

  CallV2ClientErrorCode? get lastErrorCode => _lastErrorCode;

  Future<void> start({
    required String callId,
    required String callerUid,
    required String calleeUid,
  }) async {
    if (!_featureGate.enabled) return;

    final nextIdentity = _SubscriptionIdentity(
      callId: _validateIdentifier(callId),
      callerUid: _validateIdentifier(callerUid),
      calleeUid: _validateIdentifier(calleeUid),
    );
    if (nextIdentity.callerUid == nextIdentity.calleeUid) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }

    final currentIdentity = _identity;
    if (isRunning && currentIdentity != null) {
      if (currentIdentity == nextIdentity) return;
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }

    await stop();

    final generation = ++_generation;
    final createdSubscriptions =
        <StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>[];
    try {
      createdSubscriptions.add(_callDocumentStream(nextIdentity.callId).listen(
        (document) => _handleCallDocument(generation, document),
        onError: (Object _) => _handleStreamError(generation),
      ));
      createdSubscriptions.add(_participantDocumentStream(
        nextIdentity.callId,
        nextIdentity.callerUid,
      ).listen(
        (document) => _handleCallerDocument(generation, document),
        onError: (Object _) => _handleStreamError(generation),
      ));
      createdSubscriptions.add(_participantDocumentStream(
        nextIdentity.callId,
        nextIdentity.calleeUid,
      ).listen(
        (document) => _handleCalleeDocument(generation, document),
        onError: (Object _) => _handleStreamError(generation),
      ));
    } catch (_) {
      await _cancel(createdSubscriptions);
      _lastErrorCode = CallV2ClientErrorCode.unavailable;
      _status = CallV2SubscriptionStatus.failed;
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }

    _subscriptions.addAll(createdSubscriptions);
    _identity = nextIdentity;
    _latestCallDocument = null;
    _latestCallerDocument = null;
    _latestCalleeDocument = null;
    _lastErrorCode = null;
    _status = CallV2SubscriptionStatus.listening;
  }

  Future<void> stop() async {
    _generation += 1;
    await _cancel(_subscriptions);
    _subscriptions.clear();
    _identity = null;
    _latestCallDocument = null;
    _latestCallerDocument = null;
    _latestCalleeDocument = null;
    if (_status != CallV2SubscriptionStatus.failed) {
      _status = CallV2SubscriptionStatus.stopped;
    }
  }

  void _handleCallDocument(
    int generation,
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    if (generation != _generation || !isRunning) return;
    _latestCallDocument = document;
    _combineLatest(generation);
  }

  void _handleCallerDocument(
    int generation,
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    if (generation != _generation || !isRunning) return;
    _latestCallerDocument = document;
    _combineLatest(generation);
  }

  void _handleCalleeDocument(
    int generation,
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    if (generation != _generation || !isRunning) return;
    _latestCalleeDocument = document;
    _combineLatest(generation);
  }

  void _combineLatest(int generation) {
    final callDocument = _latestCallDocument;
    final callerDocument = _latestCallerDocument;
    final calleeDocument = _latestCalleeDocument;
    if (generation != _generation ||
        callDocument == null ||
        callerDocument == null ||
        calleeDocument == null) {
      return;
    }
    try {
      final snapshot = _adapter.fromPublicDocuments(
        callDocument: callDocument,
        participantDocuments: <DocumentSnapshot<Map<String, dynamic>>>[
          callerDocument,
          calleeDocument,
        ],
      );
      if (generation != _generation || !isRunning) return;
      _lastErrorCode = null;
      _harness.injectPublicSnapshot(snapshot);
    } on FormatException {
      _lastErrorCode = CallV2ClientErrorCode.rejected;
    }
  }

  void _handleStreamError(int generation) {
    if (generation != _generation) return;
    _lastErrorCode = CallV2ClientErrorCode.unavailable;
    _status = CallV2SubscriptionStatus.failed;
    unawaited(_cancelActiveGeneration(generation));
  }

  Future<void> _cancelActiveGeneration(int generation) async {
    if (generation != _generation) return;
    await _cancel(_subscriptions);
    if (generation != _generation) return;
    _subscriptions.clear();
    _identity = null;
    _latestCallDocument = null;
    _latestCallerDocument = null;
    _latestCalleeDocument = null;
  }

  Future<void> _cancel(
    Iterable<StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
        subscriptions,
  ) async {
    for (final subscription in subscriptions.toList(growable: false)) {
      await subscription.cancel();
    }
  }

  String _validateIdentifier(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        trimmed != value ||
        trimmed.length > 128 ||
        trimmed.contains('/')) {
      throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
    }
    return trimmed;
  }
}

class _SubscriptionIdentity {
  const _SubscriptionIdentity({
    required this.callId,
    required this.callerUid,
    required this.calleeUid,
  });

  final String callId;
  final String callerUid;
  final String calleeUid;

  @override
  bool operator ==(Object other) {
    return other is _SubscriptionIdentity &&
        other.callId == callId &&
        other.callerUid == callerUid &&
        other.calleeUid == calleeUid;
  }

  @override
  int get hashCode => Object.hash(callId, callerUid, calleeUid);
}
