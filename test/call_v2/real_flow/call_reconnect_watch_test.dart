import 'package:connect_app/services/call_reconnect_watch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CallReconnectWatch watch;

  setUp(() => watch = CallReconnectWatch());
  tearDown(() => watch.reset());

  bool reconnecting() => watch.status.value?.reconnecting ?? false;

  test('only a network drop gets the grace period', () {
    expect(
      CallReconnectWatch.isNetworkDrop(
          'UserOfflineReasonType.userOfflineDropped'),
      isTrue,
    );
    expect(
      CallReconnectWatch.isNetworkDrop('UserOfflineReasonType.userOfflineQuit'),
      isFalse,
    );
    expect(CallReconnectWatch.isNetworkDrop('remote_hangup'), isFalse);
  });

  testWidgets('a remote that rejoins within the grace keeps the call',
      (tester) async {
    var expired = 0;
    watch.remoteDropped('invite_a', onExpired: () => expired += 1);
    expect(reconnecting(), isTrue);
    expect(watch.status.value!.inviteId, 'invite_a');

    await tester.pump(const Duration(seconds: 20));
    watch.remoteRejoined('invite_a');
    expect(reconnecting(), isFalse);

    await tester.pump(const Duration(seconds: 30));
    expect(expired, 0);
  });

  testWidgets('a remote that stays away ends after the grace', (tester) async {
    var expired = 0;
    watch.remoteDropped('invite_a', onExpired: () => expired += 1);
    watch.remoteDropped('invite_a', onExpired: () => expired += 1);

    await tester.pump(CallReconnectWatch.defaultRemoteGrace -
        const Duration(milliseconds: 1));
    expect(expired, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(expired, 1, reason: 'a repeated drop does not restart the grace');
  });

  testWidgets('the local limit ends a call that never recovers',
      (tester) async {
    var limit = 0;
    watch.localReconnecting('invite_a', true, onLimit: () => limit += 1);
    expect(reconnecting(), isTrue);

    await tester.pump(const Duration(seconds: 30));
    watch.localReconnecting('invite_a', false, onLimit: () => limit += 1);
    expect(reconnecting(), isFalse);
    await tester.pump(CallReconnectWatch.defaultLocalLimit);
    expect(limit, 0, reason: 'recovery cancels the limit');

    watch.localReconnecting('invite_a', true, onLimit: () => limit += 1);
    await tester.pump(CallReconnectWatch.defaultLocalLimit);
    expect(limit, 1);
  });

  testWidgets('frozen remote audio shows reconnecting only after the delay',
      (tester) async {
    watch.remoteAudioFrozen('invite_a', true);
    expect(reconnecting(), isFalse, reason: 'a short freeze does not flicker');
    await tester.pump(const Duration(milliseconds: 500));
    watch.remoteAudioFrozen('invite_a', false);
    await tester.pump(CallReconnectWatch.defaultStallDelay);
    expect(reconnecting(), isFalse);

    watch.remoteAudioFrozen('invite_a', true);
    await tester.pump(CallReconnectWatch.defaultStallDelay);
    expect(reconnecting(), isTrue);
    watch.remoteAudioFrozen('invite_a', false);
    expect(reconnecting(), isFalse);
  });

  testWidgets('a new invite or a reset drops the old timers', (tester) async {
    var expired = 0;
    watch.remoteDropped('invite_a', onExpired: () => expired += 1);
    watch.localReconnecting('invite_b', true, onLimit: () => expired += 1);
    expect(watch.status.value!.inviteId, 'invite_b');
    expect(watch.status.value!.remoteDropped, isFalse);

    watch.reset();
    expect(watch.status.value, isNull);
    await tester.pump(const Duration(minutes: 2));
    expect(expired, 0);
  });

  testWidgets('events for another invite are ignored', (tester) async {
    watch.remoteDropped('invite_a', onExpired: () {});
    watch.remoteRejoined('invite_other');
    watch.remoteAudioFrozen('invite_other', false);
    expect(watch.status.value!.remoteDropped, isTrue);
    watch.reset();
  });
}
