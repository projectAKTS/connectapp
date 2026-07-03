import 'dart:io';

import 'package:connect_app/call_v2/call_v2_api.dart';
import 'package:connect_app/call_v2/call_v2_feature_gate.dart';
import 'package:connect_app/call_v2/call_v2_production_capabilities.dart';
import 'package:connect_app/call_v2/permissions/call_v2_media_permission_gateway.dart';
import 'package:connect_app/call_v2/permissions/production/call_v2_permission_transport.dart';
import 'package:connect_app/call_v2/permissions/production/production_call_v2_media_permission_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('construction and isolation', () {
    test('constructor has no side effects and performs no permission request',
        () {
      final transport = _FakePermissionTransport();

      ProductionCallV2MediaPermissionGateway(
        featureGate: const CallV2FeatureGate(enabled: true),
        transport: transport,
      );

      expect(transport.calls, isEmpty);
    });

    test('source has no singleton in gateway, UI, settings, runtime, or writes',
        () {
      final gatewaySource = File(
        'lib/call_v2/permissions/production/'
        'production_call_v2_media_permission_gateway.dart',
      ).readAsStringSync();
      for (final forbidden in <String>[
        'package:permission_handler',
        'openAppSettings',
        'Navigator',
        'MaterialPageRoute',
        'showDialog',
        'BuildContext',
        'CallV2Runtime(',
        'CallV2Harness(',
        '.set(',
        '.update(',
        '.delete(',
        'Platform.environment',
        'String.fromEnvironment',
        'dotenv',
        'print(',
        'debugPrint',
        'developer.log',
      ]) {
        expect(gatewaySource.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('transport source has no UI or settings navigation', () {
      final source = File(
        'lib/call_v2/permissions/production/'
        'call_v2_permission_transport.dart',
      ).readAsStringSync();
      for (final forbidden in <String>[
        'openAppSettings',
        'Navigator',
        'MaterialPageRoute',
        'showDialog',
        'BuildContext',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('default permission capability remains false', () {
      expect(
        callV2NoProductionCapabilities.permissionGatewayAvailable,
        isFalse,
      );
    });
  });

  group('behavior', () {
    test('disabled gate rejects before transport access', () async {
      final transport = _FakePermissionTransport();
      final gateway = _gateway(enabled: false, transport: transport);

      await expectLater(
        gateway.request(const CallV2MediaPermissionRequest(
          requiresMicrophone: true,
          requiresCamera: true,
        )),
        throwsA(_clientError(CallV2ClientErrorCode.rejected)),
      );

      expect(transport.calls, isEmpty);
    });

    test('audio request asks only microphone', () async {
      final transport = _FakePermissionTransport();
      final gateway = _gateway(transport: transport);

      final result = await gateway.request(const CallV2MediaPermissionRequest(
        requiresMicrophone: true,
        requiresCamera: false,
      ));

      expect(transport.calls, <CallV2MediaPermission>[
        CallV2MediaPermission.microphone,
      ]);
      expect(result.microphone, CallV2PermissionStatus.granted);
      expect(result.camera, CallV2PermissionStatus.granted);
      expect(result.allRequiredGranted, isTrue);
    });

    test('video request asks microphone then camera', () async {
      final transport = _FakePermissionTransport();
      final gateway = _gateway(transport: transport);

      await gateway.request(const CallV2MediaPermissionRequest(
        requiresMicrophone: true,
        requiresCamera: true,
      ));

      expect(transport.calls, <CallV2MediaPermission>[
        CallV2MediaPermission.microphone,
        CallV2MediaPermission.camera,
      ]);
    });

    test('camera denial blocks video but not audio-only request', () async {
      final video = await _gateway(
        transport: _FakePermissionTransport(
          statuses: <CallV2MediaPermission, CallV2PermissionStatus>{
            CallV2MediaPermission.camera: CallV2PermissionStatus.denied,
          },
        ),
      ).request(const CallV2MediaPermissionRequest(
        requiresMicrophone: true,
        requiresCamera: true,
      ));

      expect(video.camera, CallV2PermissionStatus.denied);
      expect(video.allRequiredGranted, isFalse);

      final audioTransport = _FakePermissionTransport(
        statuses: <CallV2MediaPermission, CallV2PermissionStatus>{
          CallV2MediaPermission.camera: CallV2PermissionStatus.denied,
        },
      );
      final audio = await _gateway(transport: audioTransport)
          .request(const CallV2MediaPermissionRequest(
        requiresMicrophone: true,
        requiresCamera: false,
      ));

      expect(audioTransport.calls, <CallV2MediaPermission>[
        CallV2MediaPermission.microphone,
      ]);
      expect(audio.allRequiredGranted, isTrue);
    });

    test(
        'denied, permanent, restricted, and unavailable statuses are preserved',
        () async {
      for (final status in <CallV2PermissionStatus>[
        CallV2PermissionStatus.denied,
        CallV2PermissionStatus.permanentlyDenied,
        CallV2PermissionStatus.restricted,
        CallV2PermissionStatus.unavailable,
      ]) {
        final result = await _gateway(
          transport: _FakePermissionTransport(
            statuses: <CallV2MediaPermission, CallV2PermissionStatus>{
              CallV2MediaPermission.microphone: status,
            },
          ),
        ).request(const CallV2MediaPermissionRequest(
          requiresMicrophone: true,
          requiresCamera: false,
        ));

        expect(result.microphone, status);
        expect(result.allRequiredGranted, isFalse);
      }
    });

    test('transport exception normalizes unavailable without raw details',
        () async {
      final transport = _FakePermissionTransport(
        error: StateError('raw platform permission secret'),
      );

      Object? caught;
      try {
        await _gateway(transport: transport).request(
          const CallV2MediaPermissionRequest(
            requiresMicrophone: true,
            requiresCamera: true,
          ),
        );
      } catch (error) {
        caught = error;
      }

      expect(caught, isA<CallV2ClientError>());
      expect(
        (caught! as CallV2ClientError).code,
        CallV2ClientErrorCode.unavailable,
      );
      expect(caught.toString(), isNot(contains('raw platform')));
      expect(transport.calls, <CallV2MediaPermission>[
        CallV2MediaPermission.microphone,
      ]);
    });

    test(
        'one request performs one transport invocation per required permission',
        () async {
      final transport = _FakePermissionTransport();
      final gateway = _gateway(transport: transport);

      await gateway.request(const CallV2MediaPermissionRequest(
        requiresMicrophone: true,
        requiresCamera: true,
      ));

      expect(transport.calls, hasLength(2));
    });

    test('no retry, no custom cache, duplicate requests remain separate',
        () async {
      final transport = _FakePermissionTransport();
      final gateway = _gateway(transport: transport);
      const request = CallV2MediaPermissionRequest(
        requiresMicrophone: true,
        requiresCamera: false,
      );

      await gateway.request(request);
      await gateway.request(request);

      expect(transport.calls, <CallV2MediaPermission>[
        CallV2MediaPermission.microphone,
        CallV2MediaPermission.microphone,
      ]);
    });

    test('result debug output contains statuses only', () async {
      const result = CallV2MediaPermissionResult(
        requiresMicrophone: true,
        requiresCamera: true,
        microphone: CallV2PermissionStatus.granted,
        camera: CallV2PermissionStatus.permanentlyDenied,
      );

      expect(result.toString(), contains('granted'));
      expect(result.toString(), contains('permanentlyDenied'));
      expect(result.toString(), isNot(contains('platform')));
      expect(result.toString(), isNot(contains('token')));
      expect(result.toString(), isNot(contains('uid')));
    });
  });
}

ProductionCallV2MediaPermissionGateway _gateway({
  bool enabled = true,
  required CallV2PermissionTransport transport,
}) {
  return ProductionCallV2MediaPermissionGateway(
    featureGate: CallV2FeatureGate(enabled: enabled),
    transport: transport,
  );
}

Matcher _clientError(CallV2ClientErrorCode code) {
  return isA<CallV2ClientError>().having(
    (error) => error.code,
    'code',
    code,
  );
}

class _FakePermissionTransport implements CallV2PermissionTransport {
  _FakePermissionTransport({
    Map<CallV2MediaPermission, CallV2PermissionStatus>? statuses,
    this.error,
  }) : statuses =
            statuses ?? const <CallV2MediaPermission, CallV2PermissionStatus>{};

  final Map<CallV2MediaPermission, CallV2PermissionStatus> statuses;
  final Object? error;
  final calls = <CallV2MediaPermission>[];

  @override
  Future<CallV2PermissionStatus> request(
    CallV2MediaPermission permission,
  ) async {
    calls.add(permission);
    final thrown = error;
    if (thrown != null) throw thrown;
    return statuses[permission] ?? CallV2PermissionStatus.granted;
  }
}
