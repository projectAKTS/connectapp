import 'package:connect_app/call_v2/domain/call_lifecycle.dart';
import 'package:connect_app/call_v2/domain/call_snapshot.dart';
import 'package:connect_app/call_v2/domain/participant_media_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CallSnapshot.fromPublicData', () {
    test('parses the exact successful participant set', () {
      final snapshot = CallSnapshot.fromPublicData(_baseCallData());

      expect(snapshot.callId, 'call_a');
      expect(snapshot.version, 7);
      expect(snapshot.lifecycle, CallLifecycle.accepted);
      expect(snapshot.callerUid, 'caller');
      expect(snapshot.calleeUid, 'callee');
      expect(snapshot.callerMediaState, ParticipantMediaState.joined);
      expect(snapshot.calleeMediaState, ParticipantMediaState.joined);
    });

    test('rejects same caller and callee', () {
      expect(
        () => CallSnapshot.fromPublicData(
          _baseCallData()
            ..['calleeUid'] = 'caller'
            ..['participantUids'] = <String>['caller', 'caller']
            ..['participants'] = <Map<String, Object?>>[
              {
                'uid': 'caller',
                'role': 'caller',
                'mediaState': 'joined',
                'mediaVersion': 1,
              },
            ],
        ),
        throwsFormatException,
      );
    });

    test('rejects wrong participant IDs', () {
      expect(
        () => CallSnapshot.fromPublicData(
          _baseCallData()
            ..['participantUids'] = <String>['caller', 'other']
            ..['participants'] = <Map<String, Object?>>[
              {
                'uid': 'caller',
                'role': 'caller',
                'mediaState': 'joined',
                'mediaVersion': 1,
              },
              {
                'uid': 'other',
                'role': 'callee',
                'mediaState': 'joined',
                'mediaVersion': 1,
              },
            ],
        ),
        throwsFormatException,
      );
    });

    test('rejects missing caller participant', () {
      expect(
        () => CallSnapshot.fromPublicData(
          _baseCallData()
            ..['participantUids'] = <String>['caller', 'callee']
            ..['participants'] = <Map<String, Object?>>[
              {
                'uid': 'callee',
                'role': 'callee',
                'mediaState': 'joined',
                'mediaVersion': 1,
              },
            ],
        ),
        throwsFormatException,
      );
    });

    test('rejects missing callee participant', () {
      expect(
        () => CallSnapshot.fromPublicData(
          _baseCallData()
            ..['participants'] = <Map<String, Object?>>[
              {
                'uid': 'caller',
                'role': 'caller',
                'mediaState': 'joined',
                'mediaVersion': 1,
              },
            ],
        ),
        throwsFormatException,
      );
    });

    test('rejects duplicate caller and callee roles', () {
      expect(
        () => CallSnapshot.fromPublicData(
          _baseCallData()
            ..['participantUids'] = <String>['caller', 'callee']
            ..['participants'] = <Map<String, Object?>>[
              {
                'uid': 'caller',
                'role': 'caller',
                'mediaState': 'joined',
                'mediaVersion': 1,
              },
              {
                'uid': 'callee',
                'role': 'caller',
                'mediaState': 'joined',
                'mediaVersion': 1,
              },
            ],
        ),
        throwsFormatException,
      );
    });

    test('rejects duplicate participant UIDs in the public set', () {
      expect(
        () => CallSnapshot.fromPublicData(
          _baseCallData()
            ..['participantUids'] = <String>['caller', 'caller']
            ..['participants'] = <Map<String, Object?>>[
              {
                'uid': 'caller',
                'role': 'caller',
                'mediaState': 'joined',
                'mediaVersion': 1,
              },
            ],
        ),
        throwsFormatException,
      );
    });
  });
}

Map<String, Object?> _baseCallData() {
  return <String, Object?>{
    'callSystem': 'v2',
    'callId': 'call_a',
    'version': 7,
    'lifecycle': 'accepted',
    'callerUid': 'caller',
    'calleeUid': 'callee',
    'participantUids': <String>['caller', 'callee'],
    'participants': <Map<String, Object?>>[
      {
        'uid': 'caller',
        'role': 'caller',
        'mediaState': 'joined',
        'mediaVersion': 1,
      },
      {
        'uid': 'callee',
        'role': 'callee',
        'mediaState': 'joined',
        'mediaVersion': 1,
      },
    ],
  };
}
