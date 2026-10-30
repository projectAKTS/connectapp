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

  testWidgets('remote audio that stops arriving shows reconnecting',
      (tester) async {
    watch.remoteAudioReport('invite_a', 0);
    await tester.pump(const Duration(seconds: 10));
    expect(reconnecting(), isFalse, reason: 'nothing is armed before audio');

    watch.remoteAudioReport('invite_a', 32);
    await tester.pump(CallReconnectWatch.defaultAudioSilenceLimit -
        const Duration(milliseconds: 1));
    expect(reconnecting(), isFalse);
    watch.remoteAudioReport('invite_a', 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(reconnecting(), isTrue, reason: 'a zero report is no audio');

    watch.remoteAudioReport('invite_a', 30);
    expect(reconnecting(), isFalse);
    await tester.pump(const Duration(seconds: 2));
    watch.remoteAudioReport('invite_a', 31);
    await tester.pump(const Duration(seconds: 2));
    expect(reconnecting(), isFalse, reason: 'steady reports keep it clear');
    watch.reset();
  });

  testWidgets('a remote mute is not a stall', (tester) async {
    watch.remoteAudioReport('invite_a', 32);
    watch.remoteAudioMuted('invite_a', true);
    await tester.pump(CallReconnectWatch.defaultAudioSilenceLimit * 3);
    expect(reconnecting(), isFalse);

    watch.remoteAudioMuted('invite_a', false);
    watch.remoteAudioReport('invite_a', 32);
    await tester.pump(CallReconnectWatch.defaultAudioSilenceLimit);
    expect(reconnecting(), isTrue);
    watch.remoteAudioMuted('invite_a', true);
    expect(reconnecting(), isFalse, reason: 'a mute clears a stall');
    watch.remoteAudioReport('invite_a', 0);
    await tester.pump(CallReconnectWatch.defaultAudioSilenceLimit * 2);
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
    watch.remoteAudioMuted('invite_other', true);
    expect(watch.status.value!.remoteDropped, isTrue);
    watch.reset();
  });
}
