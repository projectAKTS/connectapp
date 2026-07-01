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
  starting,
  listening,
  stopped,
  failed,
}

abstract interface class CallV2FirestoreSubscriptionCoordinating {
  Future<void> start({
    required String callId,
    required String callerUid,
    required String calleeUid,
  });

  Future<void> stop();
}

class CallV2FirestoreSubscriptionCoordinator
    implements CallV2FirestoreSubscriptionCoordinating {
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
  Future<void>? _startFuture;
  _SubscriptionIdentity? _identity;
  DocumentSnapshot<Map<String, dynamic>>? _latestCallDocument;
  DocumentSnapshot<Map<String, dynamic>>? _latestCallerDocument;
  DocumentSnapshot<Map<String, dynamic>>? _latestCalleeDocument;

  bool get isRunning => _status == CallV2SubscriptionStatus.listening;

  String? get activeCallId => _identity?.callId;

  CallV2SubscriptionStatus get status => _status;

  CallV2ClientErrorCode? get lastErrorCode => _lastErrorCode;

  @override
  Future<void> start({
    required String callId,
    required String callerUid,
    required String calleeUid,
  }) {
    return Future<void>.sync(() {
      if (!_featureGate.enabled) return null;

      final nextIdentity = _SubscriptionIdentity(
        callId: _validateIdentifier(callId),
        callerUid: _validateIdentifier(callerUid),
        calleeUid: _validateIdentifier(calleeUid),
      );
      if (nextIdentity.callerUid == nextIdentity.calleeUid) {
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }

      final currentIdentity = _identity;
      if (_isSessionActive && currentIdentity != null) {
        if (currentIdentity == nextIdentity) {
          return _startFuture ?? Future<void>.value();
        }
        throw const CallV2ClientError(CallV2ClientErrorCode.rejected);
      }

      final generation = ++_generation;
      final completer = Completer<void>();
      _startFuture = completer.future;
      _identity = nextIdentity;
      _latestCallDocument = null;
      _latestCallerDocument = null;
      _latestCalleeDocument = null;
      _lastErrorCode = null;
      _status = CallV2SubscriptionStatus.starting;
      unawaited(_start(
        generation: generation,
        identity: nextIdentity,
      ).then<void>(
        (_) => completer.complete(),
        onError: (Object error, StackTrace stackTrace) {
          completer.completeError(error, stackTrace);
        },
      ));
      return completer.future;
    });
  }

  bool get _isSessionActive {
    return _status == CallV2SubscriptionStatus.starting ||
        _status == CallV2SubscriptionStatus.listening;
  }

  Future<void> _start({
    required int generation,
    required _SubscriptionIdentity identity,
  }) async {
    final createdSubscriptions =
        <StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>[];
    try {
      _addCreatedSubscription(
        generation,
        createdSubscriptions,
        _callDocumentStream(identity.callId).listen(
          (document) => _handleCallDocument(generation, document),
          onError: (Object _) => _handleStreamError(generation),
        ),
      );
      _addCreatedSubscription(
        generation,
        createdSubscriptions,
        _participantDocumentStream(
          identity.callId,
          identity.callerUid,
        ).listen(
          (document) => _handleCallerDocument(generation, document),
          onError: (Object _) => _handleStreamError(generation),
        ),
      );
      _addCreatedSubscription(
        generation,
        createdSubscriptions,
        _participantDocumentStream(
          identity.callId,
          identity.calleeUid,
        ).listen(
          (document) => _handleCalleeDocument(generation, document),
          onError: (Object _) => _handleStreamError(generation),
        ),
      );
      if (!_canCommitStartup(generation)) {
        throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
      }
    } catch (_) {
      await _failStartup(generation, createdSubscriptions);
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }

    if (!_canCommitStartup(generation)) {
      await _failStartup(generation, createdSubscriptions);
      throw const CallV2ClientError(CallV2ClientErrorCode.unavailable);
    }
    _status = CallV2SubscriptionStatus.listening;
    _startFuture = null;
  }

  @override
  Future<void> stop() async {
    final stopGeneration = ++_generation;
    final startFuture = _startFuture;
    _startFuture = null;
    await _cancel(_subscriptions);
    if (startFuture != null) {
      try {
        await startFuture;
      } on CallV2ClientError {
        // A stopped startup may report its controlled cancellation failure.
      }
    }
    if (stopGeneration != _generation) return;
    _subscriptions.clear();
    _identity = null;
    _latestCallDocument = null;
    _latestCallerDocument = null;
    _latestCalleeDocument = null;
    if (startFuture != null || _status != CallV2SubscriptionStatus.failed) {
      _status = CallV2SubscriptionStatus.stopped;
    }
  }

  void _handleCallDocument(
    int generation,
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    if (!_acceptsGeneration(generation)) return;
    _latestCallDocument = document;
    _combineLatest(generation);
  }

  void _handleCallerDocument(
    int generation,
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    if (!_acceptsGeneration(generation)) return;
    _latestCallerDocument = document;
    _combineLatest(generation);
  }

  void _handleCalleeDocument(
    int generation,
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    if (!_acceptsGeneration(generation)) return;
    _latestCalleeDocument = document;
    _combineLatest(generation);
  }

  bool _acceptsGeneration(int generation) {
    return generation == _generation &&
        (_status == CallV2SubscriptionStatus.starting ||
            _status == CallV2SubscriptionStatus.listening);
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
      if (!_acceptsGeneration(generation)) return;
      _lastErrorCode = null;
      _harness.injectPublicSnapshot(snapshot);
    } on FormatException {
      _lastErrorCode = CallV2ClientErrorCode.rejected;
    }
  }

  void _handleStreamError(int generation) {
    if (!_acceptsGeneration(generation)) return;
    _lastErrorCode = CallV2ClientErrorCode.unavailable;
    _status = CallV2SubscriptionStatus.failed;
    unawaited(_cancelActiveGeneration(generation));
  }

  void _addCreatedSubscription(
    int generation,
    List<StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>> created,
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> subscription,
  ) {
    created.add(subscription);
    if (generation == _generation) {
      _subscriptions.add(subscription);
    }
  }

  bool _canCommitStartup(int generation) {
    return generation == _generation &&
        _status == CallV2SubscriptionStatus.starting &&
        _subscriptions.length == 3;
  }

  Future<void> _failStartup(
    int generation,
    List<StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>> created,
  ) async {
    if (generation == _generation) {
      _generation += 1;
    }
    await _cancel(<StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>{
      ...created,
      ..._subscriptions,
    });
    for (final subscription in created) {
      _subscriptions.remove(subscription);
    }
    if (_status == CallV2SubscriptionStatus.starting ||
        _status == CallV2SubscriptionStatus.listening ||
        _status == CallV2SubscriptionStatus.failed) {
      _lastErrorCode = CallV2ClientErrorCode.unavailable;
      _status = CallV2SubscriptionStatus.failed;
      _identity = null;
      _latestCallDocument = null;
      _latestCallerDocument = null;
      _latestCalleeDocument = null;
    }
    _startFuture = null;
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
