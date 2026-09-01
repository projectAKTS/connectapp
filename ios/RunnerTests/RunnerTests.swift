import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  func testNativeAcceptStartsOneWatchForDuplicateExactKey() {
    let watchdog = makeWatchdog()

    XCTAssertTrue(watchdog.start(exactKey: "private-native-key"))
    XCTAssertFalse(watchdog.start(exactKey: "private-native-key"))
    XCTAssertEqual(watchdog.activeCount, 1)
  }

  func testRouteOwnershipAckCancelsWatchBeforeTimeout() {
    let timeoutDidFire = expectation(description: "timeout does not fire")
    timeoutDidFire.isInverted = true
    let watchdog = makeWatchdog(
      timeout: 0.04,
      requestExactEnd: { _ in timeoutDidFire.fulfill() }
    )

    XCTAssertTrue(watchdog.start(exactKey: "private-native-key"))
    XCTAssertTrue(watchdog.acknowledgeRouteOwned(exactKey: "private-native-key"))
    XCTAssertEqual(watchdog.activeCount, 0)
    XCTAssertTrue(watchdog.routeOwnedAck)
    wait(for: [timeoutDidFire], timeout: 0.08)
  }

  func testTimeoutEndsAndVerifiesExactNativeCall() {
    let verified = expectation(description: "exact native call verified absent")
    var active = Set(["private-native-key"])
    var ended: [String] = []
    var stages: [String] = []
    let watchdog = makeWatchdog(
      timeout: 0.01,
      record: { _, stage in
        stages.append(stage)
        if stage == "nativeCallEndVerified" { verified.fulfill() }
      },
      requestExactEnd: { key in
        ended.append(key)
        active.remove(key)
      },
      exactCallIsActive: { active.contains($0) }
    )

    XCTAssertTrue(watchdog.start(exactKey: "private-native-key"))
    wait(for: [verified], timeout: 0.2)

    XCTAssertEqual(ended, ["private-native-key"])
    XCTAssertTrue(stages.contains("nativeSafetyTimeoutFired"))
    XCTAssertTrue(stages.contains("nativeCallEndRequested"))
    XCTAssertTrue(stages.contains("nativeCallEndVerified"))
    XCTAssertFalse(watchdog.acknowledgeRouteOwned(exactKey: "private-native-key"))
  }

  func testNativeTerminalCancelsWatch() {
    let timeoutDidFire = expectation(description: "terminal cancels timeout")
    timeoutDidFire.isInverted = true
    let watchdog = makeWatchdog(
      timeout: 0.04,
      requestExactEnd: { _ in timeoutDidFire.fulfill() }
    )

    XCTAssertTrue(watchdog.start(exactKey: "private-native-key"))
    XCTAssertTrue(watchdog.terminal(exactKey: "private-native-key"))
    XCTAssertEqual(watchdog.activeCount, 0)
    wait(for: [timeoutDidFire], timeout: 0.08)
  }

  func testSequentialCallsHaveIndependentWatchOwnership() {
    let watchdog = makeWatchdog(timeout: 1)

    XCTAssertTrue(watchdog.start(exactKey: "private-native-key-a"))
    XCTAssertTrue(watchdog.acknowledgeRouteOwned(exactKey: "private-native-key-a"))
    XCTAssertTrue(watchdog.start(exactKey: "private-native-key-b"))
    XCTAssertTrue(watchdog.isWatching(exactKey: "private-native-key-b"))
    XCTAssertFalse(watchdog.isWatching(exactKey: "private-native-key-a"))
  }

  func testSafeNativeTimelineContainsNoExactOwnershipValue() {
    let ledger = CallV2SafeNativeDiagnosticLedger()
    ledger.record(exactKey: "private-native-key", stage: "pushkitReceived")
    ledger.record(exactKey: "private-native-key", stage: "callkitPresented")

    let snapshot = ledger.safeSnapshot(
      nativeWatchActive: true,
      routeOwnedAck: false,
      nativeCallActive: true,
      blockerCode: "none"
    )
    let description = String(describing: snapshot)

    XCTAssertFalse(description.contains("private-native-key"))
    XCTAssertTrue(description.contains("pushkitReceived"))
    XCTAssertTrue(description.contains("callkitPresented"))
  }

  private func makeWatchdog(
    timeout: TimeInterval = 1,
    record: @escaping (String, String) -> Void = { _, _ in },
    requestExactEnd: @escaping (String) -> Void = { _ in },
    exactCallIsActive: @escaping (String) -> Bool = { _ in false }
  ) -> CallV2NativeRouteSafetyWatchdog {
    return CallV2NativeRouteSafetyWatchdog(
      timeout: timeout,
      verificationDelay: 0.005,
      queue: DispatchQueue(label: "CallV2NativeRouteSafetyWatchdogTests"),
      record: record,
      requestExactEnd: requestExactEnd,
      exactCallIsActive: exactCallIsActive
    )
  }
}
