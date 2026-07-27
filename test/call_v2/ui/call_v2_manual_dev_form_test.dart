import 'package:connect_app/call_v2/firebase/call_v2_dev_callable_target.dart';
import 'package:connect_app/call_v2/firebase/firebase_call_v2_callable_transport.dart';
import 'package:connect_app/call_v2/permissions/call_v2_permission_adapter.dart';
import 'package:connect_app/call_v2/permissions/real_call_v2_permission_adapter.dart';
import 'package:connect_app/call_v2/rtc/agora_call_v2_rtc_adapter.dart';
import 'package:connect_app/call_v2/rtc/call_v2_rtc_adapter.dart';
import 'package:connect_app/call_v2/ui/call_v2_manual_dev_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('typing does not call backend permission or RTC clients',
      (tester) async {
    final callable = _FakeCallableClient();
    final devTarget = _FakeDevCallableTarget(
      FirebaseCallV2CallableTransport(client: _FakeCallableClient()),
    );
    final permissions = _FakePermissionClient();
    final rtc = _FakeRtcClient();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CallV2ManualDevEntry(
          callableTransport: FirebaseCallV2CallableTransport(client: callable),
          devCallableTarget: devTarget,
          permissionClient: permissions,
          rtcClient: rtc,
        ),
      ),
    ));

    await tester.enterText(
      find.byKey(const ValueKey<String>('call-v2-manual-session')),
      'session_real',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('call-v2-manual-local')),
      'local_real',
    );
    await tester.pump();

    expect(callable.calls, 0);
    expect(devTarget.creates, 0);
    expect(permissions.requests, 0);
    expect(rtc.initializes, 0);
    expect(find.text('Idle'), findsNothing);
  });

  testWidgets('create button builds runtime and then explicit buttons work',
      (tester) async {
    final callable = _FakeCallableClient();
    final devTarget = _FakeDevCallableTarget(
      FirebaseCallV2CallableTransport(client: _FakeCallableClient()),
    );
    final permissions = _FakePermissionClient();
    final rtc = _FakeRtcClient();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CallV2ManualDevEntry(
          callableTransport: FirebaseCallV2CallableTransport(client: callable),
          devCallableTarget: devTarget,
          permissionClient: permissions,
          rtcClient: rtc,
        ),
      ),
    ));

    await tester.tap(find.byKey(const ValueKey<String>('call-v2-manual-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Internal mode with real adapters').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('call-v2-manual-app')),
      'app-for-test',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('call-v2-create-manual-runtime')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('call-v2-create-manual-runtime')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Idle'), findsOneWidget);
    expect(callable.calls, 0);
    expect(devTarget.creates, 0);
    expect(permissions.requests, 0);
    expect(rtc.initializes, 0);
  });

  testWidgets('deployed dev callable target is explicit and manual-only',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final defaultCallable = _FakeCallableClient();
    final devCallable = _FakeCallableClient();
    final devTarget = _FakeDevCallableTarget(
      FirebaseCallV2CallableTransport(client: devCallable),
    );
    final permissions = _FakePermissionClient();
    final rtc = _FakeRtcClient();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CallV2ManualDevEntry(
          callableTransport:
              FirebaseCallV2CallableTransport(client: defaultCallable),
          devCallableTarget: devTarget,
          permissionClient: permissions,
          rtcClient: rtc,
        ),
      ),
    ));

    expect(devTarget.creates, 0);
    expect(defaultCallable.calls, 0);
    expect(devCallable.calls, 0);

    await tester.tap(find.byKey(const ValueKey<String>('call-v2-manual-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Internal mode with real adapters').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('call-v2-use-dev-callable')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('call-v2-use-dev-callable')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('call-v2-manual-app')),
      'app-for-test',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('call-v2-create-manual-runtime')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('call-v2-create-manual-runtime')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Idle'), findsOneWidget);
    expect(devTarget.creates, 1);
    expect(defaultCallable.calls, 0);
    expect(devCallable.calls, 0);
    expect(find.textContaining('devTargetReady'), findsOneWidget);

    await tester
        .ensureVisible(find.byKey(const ValueKey<String>('start-audio')));
    await tester.tap(find.byKey(const ValueKey<String>('start-audio')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('request-permission')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('request-permission')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('request-internal-access')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('request-internal-access')),
    );
    await tester.pumpAndSettle();

    expect(defaultCallable.calls, 0);
    expect(devCallable.calls, 1);
    expect(permissions.requests, 1);
    expect(rtc.initializes, 0);
  });
}

class _FakeCallableClient implements FirebaseCallV2CallableClient {
  int calls = 0;

  @override
  Future<Object?> call(String name, Map<String, Object?> data) async {
    calls += 1;
    return <String, Object?>{
      'status': 'ok',
      'result': <String, Object?>{
        'channelAlias': 'fake-channel',
        'rtcUid': 123,
        'expiresInSeconds': 3600,
        'token': 'fake-token',
      },
    };
  }
}

class _FakeDevCallableTarget implements CallV2DevCallableTarget {
  _FakeDevCallableTarget(this.transport);

  final FirebaseCallV2CallableTransport transport;
  int creates = 0;

  @override
  Future<FirebaseCallV2CallableTransport> createTransport() async {
    creates += 1;
    return transport;
  }

  @override
  Map<String, Object?> toSafeDebugMap() {
    return const <String, Object?>{
      'devTargetReady': true,
      'callableReachable': false,
      'selectedRegion': 'us-central1',
    };
  }
}

class _FakePermissionClient implements RealCallV2PermissionClient {
  int requests = 0;

  @override
  Future<CallV2PermissionDecision> check(
      CallV2PermissionKind permission) async {
    return CallV2PermissionDecision.granted;
  }

  @override
  Future<CallV2PermissionDecision> request(
    CallV2PermissionKind permission,
  ) async {
    requests += 1;
    return CallV2PermissionDecision.granted;
  }
}

class _FakeRtcClient implements AgoraCallV2RtcEngineClient {
  int initializes = 0;

  @override
  Future<void> initialize({
    required CallV2RtcSessionConfig config,
    required void Function(CallV2RtcEvent event) emit,
  }) async {
    initializes += 1;
  }

  @override
  Future<void> join() async {}

  @override
  Future<void> leave() async {}

  @override
  Future<void> setCameraEnabled(bool enabled) async {}

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {}

  @override
  Future<void> dispose() async {}
}
