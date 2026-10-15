import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

enum CallV2DurableDiagnosticStage {
  appLifecycleChanged,
  flutterAcceptBridgeReceived,
  acceptedRecoveryIdentityClassified,
  acceptedRecoveryHandoffStarted,
  acceptedContinuationClaimed,
  lifecycleGenerationChecked,
  transactionAttemptStarted,
  transactionRunInvoked,
  transactionCallbackEntered,
  transactionSnapshotObtained,
  transactionStatusClassified,
  transactionCompleted,
  transactionFailed,
  transactionRetryEntered,
  transactionResultReturned,
  audioSessionReadinessKnown,
  audioSessionReadinessWaiting,
  physicalMediaOwnerClaimed,
  physicalMediaOwnerRejected,
  cleanupGateRequested,
  cleanupGatePermitted,
  cleanupGateBlocked,
  tokenRequestStarted,
  mediaRuntimeStarted,
  agoraJoinCallbackReceived,
  mediaOwnedAckCompleted,
  mediaCleanupStarted,
  mediaCleanupCompleted,
  lifecycleReturnedIdle,
}

enum CallV2DurableDiagnosticOutcome {
  none,
  exactIdentityMatch,
  fallbackIdentityMatch,
  distinctIdentity,
  ownerMissing,
  ringing,
  accepted,
  joining,
  connected,
  missing,
  wrongRecipient,
  terminal,
  invalidStatus,
  invalidPayload,
  alreadyAccepted,
  superseded,
  unavailable,
  timeout,
  firebaseUnavailable,
  firebasePermissionDenied,
  firebaseAborted,
  firebaseOther,
  recoverableFailure,
  nonRecoverableFailure,
  allowed,
  blocked,
  waiting,
  completed,
}

class CallV2DurableDiagnosticEvent {
  const CallV2DurableDiagnosticEvent({
    required this.sequence,
    required this.occurredAtUtc,
    required this.stage,
    required this.appLifecycleState,
    required this.callFingerprint,
    required this.exactCallkitFingerprint,
    required this.outcome,
    this.attempt,
    this.lifecycleGeneration,
    this.generationCurrent,
  });

  factory CallV2DurableDiagnosticEvent.fromJson(Map<String, Object?> json) {
    final stageName = json['stage'];
    final outcomeName = json['outcome'];
    final occurredAt = DateTime.tryParse(
      (json['occurredAtUtc'] ?? '').toString(),
    );
    if (json['sequence'] is! int ||
        stageName is! String ||
        outcomeName is! String ||
        occurredAt == null) {
      throw const FormatException('Invalid durable diagnostic event.');
    }
    return CallV2DurableDiagnosticEvent(
      sequence: json['sequence']! as int,
      occurredAtUtc: occurredAt.toUtc(),
      stage: CallV2DurableDiagnosticStage.values.byName(stageName),
      appLifecycleState: (json['appLifecycleState'] ?? 'unknown').toString(),
      callFingerprint: (json['callFingerprint'] ?? '').toString(),
      exactCallkitFingerprint:
          (json['exactCallkitFingerprint'] ?? '').toString(),
      outcome: CallV2DurableDiagnosticOutcome.values.byName(outcomeName),
      attempt: json['attempt'] as int?,
      lifecycleGeneration: json['lifecycleGeneration'] as int?,
      generationCurrent: json['generationCurrent'] as bool?,
    );
  }

  final int sequence;
  final DateTime occurredAtUtc;
  final CallV2DurableDiagnosticStage stage;
  final String appLifecycleState;
  final String callFingerprint;
  final String exactCallkitFingerprint;
  final CallV2DurableDiagnosticOutcome outcome;
  final int? attempt;
  final int? lifecycleGeneration;
  final bool? generationCurrent;

  Map<String, Object> toSafeJson() => <String, Object>{
        'sequence': sequence,
        'occurredAtUtc': occurredAtUtc.toIso8601String(),
        'stage': stage.name,
        'appLifecycleState': appLifecycleState,
        'callFingerprint': callFingerprint,
        'exactCallkitFingerprint': exactCallkitFingerprint,
        'outcome': outcome.name,
        if (attempt != null) 'attempt': attempt!,
        if (lifecycleGeneration != null)
          'lifecycleGeneration': lifecycleGeneration!,
        if (generationCurrent != null) 'generationCurrent': generationCurrent!,
      };
}

abstract interface class CallV2DurableDiagnosticStore {
  Future<String?> read();

  Future<void> write(String encoded);
}

typedef CallV2BeforeDiagnosticSnapshotReplace = Future<void> Function(
  File preparedSnapshot,
  File target,
);

class CallV2FileDurableDiagnosticStore implements CallV2DurableDiagnosticStore {
  const CallV2FileDurableDiagnosticStore()
      : _targetFileForTest = null,
        _beforeReplaceForTest = null;

  CallV2FileDurableDiagnosticStore.debugForTest({
    required File targetFile,
    CallV2BeforeDiagnosticSnapshotReplace? beforeReplace,
  })  : _targetFileForTest = targetFile,
        _beforeReplaceForTest = beforeReplace;

  static const String relativePath =
      'call_v2_diagnostics/flutter_accepted_boundaries.json';
  static int _temporaryFileSequence = 0;

  final File? _targetFileForTest;
  final CallV2BeforeDiagnosticSnapshotReplace? _beforeReplaceForTest;

  Future<File> _file() async {
    final targetFileForTest = _targetFileForTest;
    if (targetFileForTest != null) return targetFileForTest;
    final support = await getApplicationSupportDirectory();
    return File('${support.path}/$relativePath');
  }

  @override
  Future<String?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<void> write(String encoded) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final preparedSnapshot = await _createTemporaryFile(file);
    try {
      await preparedSnapshot.writeAsString(encoded, flush: true);
      final beforeReplaceForTest = _beforeReplaceForTest;
      if (beforeReplaceForTest != null) {
        await beforeReplaceForTest(preparedSnapshot, file);
      }

      // The temporary file shares the target directory. On iOS/macOS,
      // dart:io delegates this operation to same-filesystem POSIX rename,
      // which atomically replaces an existing file.
      await preparedSnapshot.rename(file.path);
    } on Object {
      await _deleteTemporaryFile(preparedSnapshot);
      rethrow;
    }
  }

  Future<File> _createTemporaryFile(File target) async {
    for (var attempt = 0; attempt < 8; attempt += 1) {
      final sequence = _temporaryFileSequence++;
      final candidate = File(
        '${target.path}.tmp.$pid.'
        '${DateTime.now().microsecondsSinceEpoch}.$sequence',
      );
      try {
        return await candidate.create(exclusive: true);
      } on FileSystemException {
        if (attempt == 7) rethrow;
      }
    }
    throw StateError('Unable to create diagnostic snapshot file.');
  }

  Future<void> _deleteTemporaryFile(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on Object {
      // Preserve the original write failure; a later write uses a unique file.
    }
  }
}

class CallV2DurableDiagnosticRecorder {
  CallV2DurableDiagnosticRecorder({
    required CallV2DurableDiagnosticStore store,
    DateTime Function()? now,
    String Function()? appLifecycleState,
    this.maximumEvents = 384,
    this.maximumEncodedBytes = 128 * 1024,
    this.maximumAge = const Duration(days: 14),
  })  : _store = store,
        _now = now ?? DateTime.now,
        _appLifecycleState = appLifecycleState ?? _currentFlutterLifecycleState;

  factory CallV2DurableDiagnosticRecorder.production() {
    return CallV2DurableDiagnosticRecorder(
      store: const CallV2FileDurableDiagnosticStore(),
    );
  }

  static final CallV2DurableDiagnosticRecorder _production =
      CallV2DurableDiagnosticRecorder.production();
  static CallV2DurableDiagnosticRecorder _instance = _production;

  static CallV2DurableDiagnosticRecorder get instance => _instance;

  static void debugOverrideForTest(
    CallV2DurableDiagnosticRecorder? recorder,
  ) {
    var testBuild = false;
    assert(() {
      testBuild = true;
      return true;
    }());
    if (!testBuild) {
      throw StateError('Durable diagnostics override is test-only.');
    }
    _instance = recorder ?? _production;
  }

  final CallV2DurableDiagnosticStore _store;
  final DateTime Function() _now;
  final String Function() _appLifecycleState;
  final int maximumEvents;
  final int maximumEncodedBytes;
  final Duration maximumAge;

  Future<void> _writeTail = Future<void>.value();
  List<CallV2DurableDiagnosticEvent>? _events;

  void record(
    CallV2DurableDiagnosticStage stage, {
    String inviteIdentity = '',
    String exactCallkitIdentity = '',
    String? appLifecycleState,
    CallV2DurableDiagnosticOutcome outcome =
        CallV2DurableDiagnosticOutcome.none,
    int? attempt,
    int? lifecycleGeneration,
    bool? generationCurrent,
  }) {
    final pending = _PendingDurableDiagnosticEvent(
      occurredAtUtc: _now().toUtc(),
      stage: stage,
      appLifecycleState: _safeLifecycleState(
        appLifecycleState ?? _appLifecycleState(),
      ),
      callFingerprint: fingerprint(inviteIdentity, namespace: 'call'),
      exactCallkitFingerprint:
          fingerprint(exactCallkitIdentity, namespace: 'exact'),
      outcome: outcome,
      attempt: attempt,
      lifecycleGeneration: lifecycleGeneration,
      generationCurrent: generationCurrent,
    );
    _writeTail = _writeTail
        .then<void>((_) => _append(pending))
        .catchError((Object _, StackTrace __) {});
  }

  Future<void> flush() async {
    try {
      await _writeTail;
    } on Object {
      // Diagnostics must never affect call handling.
    }
  }

  Future<List<CallV2DurableDiagnosticEvent>> readPersisted() async {
    await flush();
    try {
      final loaded = await _load();
      return List<CallV2DurableDiagnosticEvent>.unmodifiable(loaded);
    } on Object {
      return const <CallV2DurableDiagnosticEvent>[];
    }
  }

  static String fingerprint(
    String raw, {
    required String namespace,
  }) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) return '';
    final digest = sha256.convert(
      utf8.encode('helperly-call-v2-diagnostics-v1|$namespace|$normalized'),
    );
    return digest.toString().substring(0, 16);
  }

  Future<void> _append(_PendingDurableDiagnosticEvent pending) async {
    final committedEvents = await _load();
    final candidateEvents = List<CallV2DurableDiagnosticEvent>.of(
      committedEvents,
    );
    final nextSequence =
        candidateEvents.isEmpty ? 1 : candidateEvents.last.sequence + 1;
    candidateEvents.add(pending.materialize(nextSequence));
    _trim(candidateEvents, pending.occurredAtUtc);
    var encoded = _encode(candidateEvents);
    while (candidateEvents.length > 1 &&
        utf8.encode(encoded).length > maximumEncodedBytes) {
      candidateEvents.removeAt(0);
      encoded = _encode(candidateEvents);
    }
    await _store.write(encoded);
    _events = candidateEvents;
  }

  Future<List<CallV2DurableDiagnosticEvent>> _load() async {
    final cached = _events;
    if (cached != null) return cached;
    final loaded = <CallV2DurableDiagnosticEvent>[];
    try {
      final encoded = await _store.read();
      if (encoded != null && encoded.trim().isNotEmpty) {
        final root = jsonDecode(encoded);
        if (root is Map && root['events'] is List) {
          for (final raw in root['events'] as List<dynamic>) {
            if (raw is! Map) continue;
            try {
              loaded.add(CallV2DurableDiagnosticEvent.fromJson(
                Map<String, Object?>.from(raw.cast<dynamic, dynamic>()),
              ));
            } on Object {
              // Ignore only the malformed entry and preserve the rest.
            }
          }
        }
      }
    } on Object {
      // A missing or damaged diagnostics file must not affect calling.
    }
    loaded.sort((a, b) => a.sequence.compareTo(b.sequence));
    _events = loaded;
    return loaded;
  }

  void _trim(List<CallV2DurableDiagnosticEvent> events, DateTime nowUtc) {
    final cutoff = nowUtc.subtract(maximumAge);
    events.removeWhere((event) => event.occurredAtUtc.isBefore(cutoff));
    if (events.length > maximumEvents) {
      events.removeRange(0, events.length - maximumEvents);
    }
  }

  String _encode(List<CallV2DurableDiagnosticEvent> events) {
    return jsonEncode(<String, Object>{
      'version': 1,
      'events': events.map((event) => event.toSafeJson()).toList(),
    });
  }

  static String _currentFlutterLifecycleState() {
    try {
      return WidgetsBinding.instance.lifecycleState?.name ?? 'unknown';
    } on Object {
      return 'unknown';
    }
  }

  static String _safeLifecycleState(String value) {
    const allowed = <String>{
      'resumed',
      'inactive',
      'hidden',
      'paused',
      'detached',
      'unknown',
    };
    final normalized = value.trim().toLowerCase();
    return allowed.contains(normalized) ? normalized : 'unknown';
  }
}

class _PendingDurableDiagnosticEvent {
  const _PendingDurableDiagnosticEvent({
    required this.occurredAtUtc,
    required this.stage,
    required this.appLifecycleState,
    required this.callFingerprint,
    required this.exactCallkitFingerprint,
    required this.outcome,
    required this.attempt,
    required this.lifecycleGeneration,
    required this.generationCurrent,
  });

  final DateTime occurredAtUtc;
  final CallV2DurableDiagnosticStage stage;
  final String appLifecycleState;
  final String callFingerprint;
  final String exactCallkitFingerprint;
  final CallV2DurableDiagnosticOutcome outcome;
  final int? attempt;
  final int? lifecycleGeneration;
  final bool? generationCurrent;

  CallV2DurableDiagnosticEvent materialize(int sequence) {
    return CallV2DurableDiagnosticEvent(
      sequence: sequence,
      occurredAtUtc: occurredAtUtc,
      stage: stage,
      appLifecycleState: appLifecycleState,
      callFingerprint: callFingerprint,
      exactCallkitFingerprint: exactCallkitFingerprint,
      outcome: outcome,
      attempt: attempt,
      lifecycleGeneration: lifecycleGeneration,
      generationCurrent: generationCurrent,
    );
  }
}
