import 'dart:async';
import 'dart:collection';

import 'package:flutter/services.dart';

enum CallV2PhysicalDiagnosticStage {
  pushkitReceived,
  callkitPresented,
  nativeAcceptObserved,
  nativeAcceptBridgeDispatched,
  flutterAcceptBridgeReceived,
  acceptedOwnershipRecorded,
  previousTeardownCompleted,
  appResumed,
  navigatorReady,
  routeAttemptStarted,
  routeOpened,
  rtcSetupStarted,
  agoraJoinAttempted,
  agoraJoined,
  remoteJoined,
  nativeCallStillActive,
  terminalObserved,
  nativeSafetyWatchStarted,
  nativeRouteOwnedAckReceived,
  nativeSafetyTimeoutFired,
  nativeCallEndRequested,
  nativeCallEnded,
  nativeCallEndVerified,
}

class CallV2PhysicalDiagnosticEntry {
  const CallV2PhysicalDiagnosticEntry({
    required this.sequence,
    required this.elapsedMilliseconds,
    required this.stage,
  });

  final int sequence;
  final int elapsedMilliseconds;
  final CallV2PhysicalDiagnosticStage stage;

  Map<String, Object> toSafeDebugMap() => <String, Object>{
        'sequence': sequence,
        'elapsedMilliseconds': elapsedMilliseconds,
        'stage': stage.name,
      };
}

class CallV2PhysicalDiagnosticTimeline {
  const CallV2PhysicalDiagnosticTimeline({
    required this.displayNumber,
    required this.entries,
  });

  final int displayNumber;
  final List<CallV2PhysicalDiagnosticEntry> entries;

  Map<String, Object> toSafeDebugMap() => <String, Object>{
        'displayNumber': displayNumber,
        'entries': entries
            .map((entry) => entry.toSafeDebugMap())
            .toList(growable: false),
      };
}

abstract interface class CallV2NativeDiagnosticBridge {
  Future<Object?> loadSafeTimeline();

  Future<bool> acknowledgeRouteOwnership(String exactNativeKey);
}

class MethodChannelCallV2NativeDiagnosticBridge
    implements CallV2NativeDiagnosticBridge {
  const MethodChannelCallV2NativeDiagnosticBridge();

  static const MethodChannel _channel = MethodChannel('connectapp/pushTokens');

  @override
  Future<Object?> loadSafeTimeline() {
    return _channel.invokeMethod<Object?>('getCallV2SafeDiagnosticTimeline');
  }

  @override
  Future<bool> acknowledgeRouteOwnership(String exactNativeKey) async {
    if (exactNativeKey.trim().isEmpty) return false;
    final result = await _channel.invokeMethod<Object?>(
      'callkitRouteOwned',
      <String, Object>{'callkitId': exactNativeKey},
    );
    return result == true;
  }
}

class CallV2PhysicalDiagnosticLedger {
  CallV2PhysicalDiagnosticLedger({
    CallV2NativeDiagnosticBridge? nativeBridge,
    DateTime Function()? now,
  })  : _nativeBridge =
            nativeBridge ?? const MethodChannelCallV2NativeDiagnosticBridge(),
        _now = now ?? DateTime.now;

  static final CallV2PhysicalDiagnosticLedger instance =
      CallV2PhysicalDiagnosticLedger();

  static const int maximumRetainedCalls = 2;

  final CallV2NativeDiagnosticBridge _nativeBridge;
  final DateTime Function() _now;
  final LinkedHashMap<String, _MutableTimeline> _calls =
      LinkedHashMap<String, _MutableTimeline>();
  final Map<int, String> _nativeOrdinalOwners = <int, String>{};

  String? _activeOwner;
  int _nextSyntheticOrdinal = 1;
  bool _nativeWatchActive = false;
  bool _routeOwnedAck = false;
  bool _nativeCallActive = false;
  int _routeOpenCount = 0;
  int _rtcSetupOwnerCount = 0;
  String _blockerCode = 'none';

  void beginAcceptedNativeCall({
    required String exactNativeKey,
    int? nativeOrdinal,
    int? startedAtEpochMilliseconds,
  }) {
    final owner = exactNativeKey.trim();
    if (owner.isEmpty) return;
    final ordinal = nativeOrdinal != null && nativeOrdinal > 0
        ? nativeOrdinal
        : _nextSyntheticOrdinal++;
    final startedAt =
        startedAtEpochMilliseconds != null && startedAtEpochMilliseconds > 0
            ? DateTime.fromMillisecondsSinceEpoch(startedAtEpochMilliseconds)
            : _now();
    final existing = _calls.remove(owner);
    _calls[owner] = existing ??
        _MutableTimeline(
          nativeOrdinal: ordinal,
          startedAt: startedAt,
        );
    _nativeOrdinalOwners[ordinal] = owner;
    _activeOwner = owner;
    _nativeWatchActive = true;
    _routeOwnedAck = false;
    _nativeCallActive = true;
    _blockerCode = 'none';
    _trim();
  }

  void record(
    CallV2PhysicalDiagnosticStage stage, {
    String? exactNativeKey,
  }) {
    final owner = exactNativeKey?.trim().isNotEmpty == true
        ? exactNativeKey!.trim()
        : _activeOwner;
    if (owner == null) return;
    final timeline = _calls[owner];
    if (timeline == null) return;
    timeline.add(
      stage: stage,
      elapsedMilliseconds: _now()
          .difference(timeline.startedAt)
          .inMilliseconds
          .clamp(0, 1 << 31),
      sourceOrder: timeline.nextSourceOrder++,
    );
    switch (stage) {
      case CallV2PhysicalDiagnosticStage.routeOpened:
        _routeOpenCount += 1;
      case CallV2PhysicalDiagnosticStage.rtcSetupStarted:
        _rtcSetupOwnerCount += 1;
      case CallV2PhysicalDiagnosticStage.nativeRouteOwnedAckReceived:
        _routeOwnedAck = true;
        _nativeWatchActive = false;
      case CallV2PhysicalDiagnosticStage.nativeSafetyTimeoutFired:
        _blockerCode = 'native_route_timeout';
      case CallV2PhysicalDiagnosticStage.nativeCallEnded:
      case CallV2PhysicalDiagnosticStage.nativeCallEndVerified:
        _nativeCallActive = false;
        _nativeWatchActive = false;
      default:
        break;
    }
  }

  Future<bool> acknowledgeRouteOpened(String exactNativeKey) async {
    final owner = exactNativeKey.trim();
    if (owner.isEmpty || !_calls.containsKey(owner)) return false;
    try {
      final acknowledged = await _nativeBridge.acknowledgeRouteOwnership(owner);
      if (acknowledged) {
        record(
          CallV2PhysicalDiagnosticStage.nativeRouteOwnedAckReceived,
          exactNativeKey: owner,
        );
      }
      return acknowledged;
    } on Object {
      _blockerCode = 'native_ack_unavailable';
      return false;
    }
  }

  Future<void> refreshNativeTimeline() async {
    try {
      final raw = await _nativeBridge.loadSafeTimeline();
      _mergeNativeTimeline(raw);
    } on Object {
      _blockerCode = 'native_diagnostics_unavailable';
    }
  }

  List<CallV2PhysicalDiagnosticTimeline> safeTimelines() {
    final retained = _calls.values.toList(growable: false);
    return List<CallV2PhysicalDiagnosticTimeline>.generate(
      retained.length,
      (index) {
        final sorted = retained[index].entries.toList()
          ..sort((a, b) {
            final elapsed = a.elapsedMilliseconds.compareTo(
              b.elapsedMilliseconds,
            );
            return elapsed != 0
                ? elapsed
                : a.sourceOrder.compareTo(b.sourceOrder);
          });
        return CallV2PhysicalDiagnosticTimeline(
          displayNumber: index + 1,
          entries: List<CallV2PhysicalDiagnosticEntry>.generate(
            sorted.length,
            (entryIndex) => CallV2PhysicalDiagnosticEntry(
              sequence: entryIndex + 1,
              elapsedMilliseconds: sorted[entryIndex].elapsedMilliseconds,
              stage: sorted[entryIndex].stage,
            ),
            growable: false,
          ),
        );
      },
      growable: false,
    );
  }

  Map<String, Object> safeState() => <String, Object>{
        'nativeWatchActive': _nativeWatchActive,
        'routeOwnedAck': _routeOwnedAck,
        'nativeCallActive': _nativeCallActive,
        'routeOpenCount': _routeOpenCount,
        'rtcSetupOwnerCount': _rtcSetupOwnerCount,
        'blockerCode': _blockerCode,
      };

  String buildSafeReport() {
    final buffer = StringBuffer();
    for (final timeline in safeTimelines()) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln('CALL ${timeline.displayNumber}:');
      for (final entry in timeline.entries) {
        final sequence = entry.sequence.toString().padLeft(2, '0');
        buffer.writeln(
          '$sequence ${entry.stage.name} +${entry.elapsedMilliseconds}ms',
        );
      }
    }
    if (buffer.isNotEmpty) buffer.writeln();
    buffer.writeln('SAFE STATE:');
    safeState().forEach((key, value) => buffer.writeln('$key=$value'));
    return buffer.toString().trimRight();
  }

  void resetForTest() {
    _calls.clear();
    _nativeOrdinalOwners.clear();
    _activeOwner = null;
    _nextSyntheticOrdinal = 1;
    _nativeWatchActive = false;
    _routeOwnedAck = false;
    _nativeCallActive = false;
    _routeOpenCount = 0;
    _rtcSetupOwnerCount = 0;
    _blockerCode = 'none';
  }

  void _mergeNativeTimeline(Object? raw) {
    if (raw is! Map) return;
    final normalized = Map<Object?, Object?>.from(raw);
    final calls = normalized['calls'];
    if (calls is Iterable) {
      for (final rawCall in calls) {
        if (rawCall is! Map) continue;
        final call = Map<Object?, Object?>.from(rawCall);
        final ordinal = call['ordinal'];
        if (ordinal is! int || ordinal <= 0) continue;
        final owner = _nativeOrdinalOwners[ordinal] ?? 'nativeOrdinal:$ordinal';
        _nativeOrdinalOwners[ordinal] = owner;
        final startedAt = call['startedAtEpochMilliseconds'];
        final timeline = _calls.remove(owner) ??
            _MutableTimeline(
              nativeOrdinal: ordinal,
              startedAt: startedAt is int && startedAt > 0
                  ? DateTime.fromMillisecondsSinceEpoch(startedAt)
                  : _now(),
            );
        final entries = call['entries'];
        if (entries is Iterable) {
          for (final rawEntry in entries) {
            if (rawEntry is! Map) continue;
            final entry = Map<Object?, Object?>.from(rawEntry);
            final stageName = entry['stage'];
            final elapsed = entry['elapsedMilliseconds'];
            final nativeSequence = entry['sequence'];
            if (stageName is! String || elapsed is! int) continue;
            final stage = _stageByName(stageName);
            if (stage == null) continue;
            timeline.addNative(
              stage: stage,
              elapsedMilliseconds: elapsed.clamp(0, 1 << 31),
              nativeSequence: nativeSequence is int ? nativeSequence : 0,
            );
          }
        }
        _calls[owner] = timeline;
      }
      _trim();
    }
    _nativeWatchActive = normalized['nativeWatchActive'] == true;
    _routeOwnedAck = normalized['routeOwnedAck'] == true;
    _nativeCallActive = normalized['nativeCallActive'] == true;
    final blocker = normalized['blockerCode'];
    if (blocker is String && blocker.isNotEmpty) _blockerCode = blocker;
  }

  CallV2PhysicalDiagnosticStage? _stageByName(String name) {
    for (final stage in CallV2PhysicalDiagnosticStage.values) {
      if (stage.name == name) return stage;
    }
    return null;
  }

  void _trim() {
    while (_calls.length > maximumRetainedCalls) {
      final oldest = _calls.keys.first;
      final removed = _calls.remove(oldest);
      if (removed != null) {
        _nativeOrdinalOwners.remove(removed.nativeOrdinal);
      }
      if (_activeOwner == oldest) _activeOwner = _calls.keys.lastOrNull;
    }
  }
}

class _MutableTimeline {
  _MutableTimeline({
    required this.nativeOrdinal,
    required this.startedAt,
  });

  final int nativeOrdinal;
  final DateTime startedAt;
  final List<_MutableEntry> entries = <_MutableEntry>[];
  final Set<String> _nativeKeys = <String>{};
  int nextSourceOrder = 1000000;

  void add({
    required CallV2PhysicalDiagnosticStage stage,
    required int elapsedMilliseconds,
    required int sourceOrder,
  }) {
    entries.add(_MutableEntry(
      elapsedMilliseconds: elapsedMilliseconds,
      stage: stage,
      sourceOrder: sourceOrder,
    ));
  }

  void addNative({
    required CallV2PhysicalDiagnosticStage stage,
    required int elapsedMilliseconds,
    required int nativeSequence,
  }) {
    final key = '${stage.name}:$elapsedMilliseconds:$nativeSequence';
    if (!_nativeKeys.add(key)) return;
    add(
      stage: stage,
      elapsedMilliseconds: elapsedMilliseconds,
      sourceOrder: nativeSequence,
    );
  }
}

class _MutableEntry {
  const _MutableEntry({
    required this.elapsedMilliseconds,
    required this.stage,
    required this.sourceOrder,
  });

  final int elapsedMilliseconds;
  final CallV2PhysicalDiagnosticStage stage;
  final int sourceOrder;
}

extension on Iterable<String> {
  String? get lastOrNull => isEmpty ? null : last;
}
