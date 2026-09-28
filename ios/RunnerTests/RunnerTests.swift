import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  func testExactCallkitEndRetryTargetsOnlySuppliedUuidDespiteNewerGlobalState() {
    let exactA = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
    let exactB = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!
    var simulatedPluginGlobalUuid = exactB
    var active = Set([exactA, exactB])
    var requested: [UUID] = []
    let requester = CallV2ExactCallkitEndRequester { uuid, completion in
      requested.append(uuid)
      active.remove(uuid)
      completion(true)
    }

    var firstResult: Bool?
    requester.end(exactId: exactA.uuidString) { firstResult = $0 }

    XCTAssertEqual(firstResult, true)
    XCTAssertEqual(requested, [exactA])
    XCTAssertFalse(active.contains(exactA))
    XCTAssertTrue(active.contains(exactB))
    XCTAssertEqual(simulatedPluginGlobalUuid, exactB)

    simulatedPluginGlobalUuid = exactB
    var duplicateResult: Bool?
    requester.end(exactId: exactA.uuidString) { duplicateResult = $0 }
    XCTAssertEqual(duplicateResult, true)
    XCTAssertEqual(requested, [exactA, exactA])
    XCTAssertTrue(active.contains(exactB))
  }

  func testExactCallkitEndCoalescesConcurrentRequestsOnlyWhileInFlight() {
    let exactA = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
    var requested: [UUID] = []
    var pendingCompletion: ((Bool) -> Void)?
    var results: [Bool] = []
    let requester = CallV2ExactCallkitEndRequester { uuid, completion in
      requested.append(uuid)
      pendingCompletion = completion
    }

    requester.end(exactId: exactA.uuidString) { results.append($0) }
    requester.end(exactId: exactA.uuidString) { results.append($0) }

    XCTAssertEqual(requested, [exactA])
    XCTAssertTrue(results.isEmpty)
    pendingCompletion?(true)
    XCTAssertEqual(results, [true, true])
  }

  func testExactCallkitEndAllowsLaterRetryAfterSuccessfulRequest() {
    let exactA = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
    var requested: [UUID] = []
    let requester = CallV2ExactCallkitEndRequester { uuid, completion in
      requested.append(uuid)
      completion(true)
    }

    requester.end(exactId: exactA.uuidString) { _ in }
    requester.end(exactId: exactA.uuidString) { _ in }

    XCTAssertEqual(requested, [exactA, exactA])
  }

  func testExactCallkitEndRejectsInvalidUuidWithoutNativeTransaction() {
    var requestCount = 0
    var result: Bool?
    let requester = CallV2ExactCallkitEndRequester { _, completion in
      requestCount += 1
      completion(true)
    }

    requester.end(exactId: "not-a-uuid") { result = $0 }

    XCTAssertEqual(result, false)
    XCTAssertEqual(requestCount, 0)
  }

  func testWatchdogEscalationSubmitsSecondExactEndAfterObserverStillActive() {
    let verified = expectation(description: "second exact end verifies absence")
    let exactA = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
    let exactB = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!
    let queue = DispatchQueue(label: "CallV2ExactEndEscalationTests")
    var active = Set([exactA, exactB])
    var requested: [UUID] = []
    var stages: [String] = []
    var verifiedKeys: [String] = []
    let requester = CallV2ExactCallkitEndRequester { uuid, completion in
      requested.append(uuid)
      if requested.filter({ $0 == exactA }).count == 2 {
        active.remove(exactA)
      }
      completion(true)
    }
    let watchdog = CallV2NativeRouteSafetyWatchdog(
      timeout: 0.01,
      verificationDelay: 0.005,
      queue: queue,
      record: { _, stage in stages.append(stage) },
      requestExactEnd: { exactKey in
        requester.end(exactId: exactKey) { _ in }
      },
      exactCallIsActive: { exactKey in
        guard let uuid = UUID(uuidString: exactKey) else { return false }
        return active.contains(uuid)
      },
      exactEndVerified: { exactKey in
        verifiedKeys.append(exactKey)
        verified.fulfill()
      }
    )

    XCTAssertTrue(watchdog.start(exactKey: exactA.uuidString))
    wait(for: [verified], timeout: 0.2)

    XCTAssertEqual(requested, [exactA, exactA])
    XCTAssertFalse(requested.contains(exactB))
    XCTAssertFalse(active.contains(exactA))
    XCTAssertTrue(active.contains(exactB))
    XCTAssertEqual(stages.filter { $0 == "nativeCallEnded" }.count, 1)
    XCTAssertEqual(stages.filter { $0 == "nativeCallEndVerified" }.count, 1)
    XCTAssertEqual(verifiedKeys.count, 1)
    XCTAssertNotEqual(watchdog.blockerCode, "native_end_unverified")
  }

  func testNativeIdentityIgnoresStalePersistedAcceptedState() {
    var generated = ["exact-a", "exact-b"]
    let allocator = CallV2NativeCallkitIdentityAllocator {
      generated.removeFirst()
    }

    let incoming = allocator.exactIdForIncoming(
      logicalKey: "raw:same-invite",
      existingExactId: "stale-exact-a",
      isActive: false
    )

    XCTAssertEqual(incoming, "exact-a")
    XCTAssertNotEqual(incoming, "stale-exact-a")
  }

  func testNativeIdentityIgnoresStalePersistedPresentedState() {
    var generated = ["exact-b"]
    let allocator = CallV2NativeCallkitIdentityAllocator {
      generated.removeFirst()
    }

    let incoming = allocator.exactIdForIncoming(
      logicalKey: "raw:same-invite",
      existingExactId: "stale-presented-a",
      isActive: false
    )

    XCTAssertEqual(incoming, "exact-b")
    XCTAssertNotEqual(incoming, "stale-presented-a")
  }

  func testNativeIdentityReusesSameProcessPresentationBeforeCxActive() {
    var generated = ["exact-a", "exact-b"]
    let allocator = CallV2NativeCallkitIdentityAllocator {
      generated.removeFirst()
    }

    let first = allocator.exactIdForIncoming(
      logicalKey: "raw:same-invite",
      existingExactId: "",
      isActive: false
    )
    let duplicate = allocator.exactIdForIncoming(
      logicalKey: "raw:same-invite",
      existingExactId: first,
      isActive: false
    )

    XCTAssertEqual(first, "exact-a")
    XCTAssertEqual(duplicate, "exact-a")
  }

  func testNativeIdentityReusesSameProcessActivePresentation() {
    var generated = ["exact-a", "exact-b"]
    let allocator = CallV2NativeCallkitIdentityAllocator {
      generated.removeFirst()
    }

    let first = allocator.exactIdForIncoming(
      logicalKey: "raw:same-invite",
      existingExactId: "",
      isActive: false
    )
    let duplicate = allocator.exactIdForIncoming(
      logicalKey: "raw:same-invite",
      existingExactId: first,
      isActive: true
    )

    XCTAssertEqual(first, "exact-a")
    XCTAssertEqual(duplicate, "exact-a")
  }

  func testNativeIdentityReleaseAllowsFreshSequentialPresentation() {
    var generated = ["exact-a", "exact-b"]
    let allocator = CallV2NativeCallkitIdentityAllocator {
      generated.removeFirst()
    }

    let first = allocator.exactIdForIncoming(
      logicalKey: "raw:same-invite",
      existingExactId: "",
      isActive: false
    )
    allocator.release(exactId: first)
    let sequential = allocator.exactIdForIncoming(
      logicalKey: "raw:same-invite",
      existingExactId: first,
      isActive: false
    )

    XCTAssertEqual(first, "exact-a")
    XCTAssertEqual(sequential, "exact-b")
  }

  func testNativeIdentityProcessRestartAllocatesFreshPresentation() {
    var firstGenerated = ["exact-a"]
    let firstAllocator = CallV2NativeCallkitIdentityAllocator {
      firstGenerated.removeFirst()
    }
    let first = firstAllocator.exactIdForIncoming(
      logicalKey: "raw:same-invite",
      existingExactId: "",
      isActive: false
    )

    var restartedGenerated = ["exact-b"]
    let restartedAllocator = CallV2NativeCallkitIdentityAllocator {
      restartedGenerated.removeFirst()
    }
    let afterRestart = restartedAllocator.exactIdForIncoming(
      logicalKey: "raw:same-invite",
      existingExactId: first,
      isActive: false
    )

    XCTAssertEqual(first, "exact-a")
    XCTAssertEqual(afterRestart, "exact-b")
  }

  func testNativeIdentityKeepsTerminalCorrelationSeparateFromIncomingReuse() {
    var generated = ["exact-a", "exact-b"]
    let allocator = CallV2NativeCallkitIdentityAllocator {
      generated.removeFirst()
    }
    let first = allocator.exactIdForIncoming(
      logicalKey: "raw:same-invite",
      existingExactId: "",
      isActive: false
    )
    allocator.release(exactId: first)

    let terminal = allocator.exactIdForTerminal(
      existingExactId: first,
      fallbackExactId: "fallback-derived"
    )
    let nextIncoming = allocator.exactIdForIncoming(
      logicalKey: "raw:same-invite",
      existingExactId: first,
      isActive: false
    )

    XCTAssertEqual(terminal, "exact-a")
    XCTAssertEqual(nextIncoming, "exact-b")
  }

  func testNativeExactEndVerificationClearsLivePresentationOwnership() {
    var generated = ["exact-a", "exact-b"]
    let allocator = CallV2NativeCallkitIdentityAllocator {
      generated.removeFirst()
    }
    let first = allocator.exactIdForIncoming(
      logicalKey: "raw:same-invite",
      existingExactId: "",
      isActive: false
    )

    XCTAssertTrue(allocator.hasLivePresentation(logicalKey: "raw:same-invite"))
    allocator.release(exactId: first)
    XCTAssertFalse(allocator.hasLivePresentation(logicalKey: "raw:same-invite"))

    let second = allocator.exactIdForIncoming(
      logicalKey: "raw:same-invite",
      existingExactId: first,
      isActive: false
    )
    XCTAssertEqual(second, "exact-b")
  }

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

  func testTimeoutReportsExactEndVerificationOnce() {
    let verified = expectation(description: "verification callback")
    var active = Set(["private-native-key"])
    var verifiedKeys: [String] = []
    let watchdog = CallV2NativeRouteSafetyWatchdog(
      timeout: 0.01,
      verificationDelay: 0.005,
      queue: DispatchQueue(label: "CallV2NativeRouteSafetyWatchdogCallbackTests"),
      record: { _, _ in },
      requestExactEnd: { key in active.remove(key) },
      exactCallIsActive: { active.contains($0) },
      exactEndVerified: { key in
        verifiedKeys.append(key)
        verified.fulfill()
      }
    )

    XCTAssertTrue(watchdog.start(exactKey: "private-native-key"))
    wait(for: [verified], timeout: 0.2)
    XCTAssertEqual(verifiedKeys, ["private-native-key"])
  }

  func testWatchdogVerifiedEndReleasesLiveIdentityBeforeNextIncoming() {
    let verified = expectation(description: "watchdog verifies exact native end")
    var generated = ["exact-a", "exact-b"]
    let allocator = CallV2NativeCallkitIdentityAllocator {
      generated.removeFirst()
    }
    let logicalKey = "raw:same-invite"
    let first = allocator.exactIdForIncoming(
      logicalKey: logicalKey,
      existingExactId: "",
      isActive: false
    )
    var active = Set([first])
    var verifiedKeys: [String] = []
    let watchdog = CallV2NativeRouteSafetyWatchdog(
      timeout: 0.01,
      verificationDelay: 0.005,
      queue: DispatchQueue(label: "CallV2NativeRouteSafetyWatchdogReleaseTests"),
      record: { _, _ in },
      requestExactEnd: { key in active.remove(key) },
      exactCallIsActive: { active.contains($0) },
      exactEndVerified: { key in
        allocator.release(exactId: key)
        verifiedKeys.append(key)
        verified.fulfill()
      }
    )

    XCTAssertEqual(first, "exact-a")
    XCTAssertTrue(allocator.hasLivePresentation(logicalKey: logicalKey))
    XCTAssertTrue(watchdog.start(exactKey: first))
    wait(for: [verified], timeout: 0.2)
    XCTAssertEqual(verifiedKeys, ["exact-a"])
    XCTAssertFalse(allocator.hasLivePresentation(logicalKey: logicalKey))

    let second = allocator.exactIdForIncoming(
      logicalKey: logicalKey,
      existingExactId: first,
      isActive: false
    )
    XCTAssertEqual(second, "exact-b")
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
