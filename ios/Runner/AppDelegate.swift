import Flutter
import UIKit
import PushKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications
import flutter_callkit_incoming
import AVFAudio
import CallKit

@main
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate, CallkitIncomingAppDelegate {
  private let pushTokenChannelName = "connectapp/pushTokens"
  private let apnsTokenStoreKey = "connectapp.apnsToken"
  private let apnsErrorStoreKey = "connectapp.apnsError"
  private let voipTokenStoreKey = "connectapp.voipToken"
  private let lastPushkitIncomingAtStoreKey = "connectapp.lastPushkitIncomingAt"
  private let lastPushkitIncomingCallIdStoreKey = "connectapp.lastPushkitIncomingCallId"
  private let lastPushkitIncomingChannelStoreKey = "connectapp.lastPushkitIncomingChannel"
  private let lastPushkitIncomingCallkitIdStoreKey = "connectapp.lastPushkitIncomingCallkitId"
  private let lastPushkitStageStoreKey = "connectapp.lastPushkitStage"
  private let lastPushkitDetailStoreKey = "connectapp.lastPushkitDetail"
  private let lastPushkitPayloadTypeStoreKey = "connectapp.lastPushkitPayloadType"
  private let lastCallkitAcceptedAtStoreKey = "connectapp.lastCallkitAcceptedAt"
  private let lastCallkitAcceptedInviteIdStoreKey = "connectapp.lastCallkitAcceptedInviteId"
  private let lastCallkitAcceptedChannelStoreKey = "connectapp.lastCallkitAcceptedChannel"
  private let lastCallkitAcceptedCallkitIdStoreKey = "connectapp.lastCallkitAcceptedCallkitId"
  private let lastCallkitAcceptedFromNameStoreKey = "connectapp.lastCallkitAcceptedFromName"
  private let lastCallkitAcceptedFromUidStoreKey = "connectapp.lastCallkitAcceptedFromUid"
  private let lastCallkitAcceptedIsVideoStoreKey = "connectapp.lastCallkitAcceptedIsVideo"
  private let lastCallkitEventStoreKey = "connectapp.lastCallkitEvent"
  private let lastCallkitEventAtStoreKey = "connectapp.lastCallkitEventAt"
  private let lastCallkitEventCallkitIdStoreKey = "connectapp.lastCallkitEventCallkitId"
  private let lastCallkitEventInviteIdStoreKey = "connectapp.lastCallkitEventInviteId"
  private let lastCallkitEventChannelStoreKey = "connectapp.lastCallkitEventChannel"
  private let callkitPresentationLedgerStoreKey = "connectapp.callkitPresentationLedger"
  private let callkitPresentationLedgerTtlSeconds: TimeInterval = 120
  private var voipRegistry: PKPushRegistry?
  private var pushTokenChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: pushTokenChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      pushTokenChannel = channel
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self else {
          result(FlutterError(code: "UNAVAILABLE", message: "AppDelegate unavailable", details: nil))
          return
        }
        if call.method == "getStoredPushTokens" {
          let defaults = UserDefaults.standard
          let apns = defaults.string(forKey: self.apnsTokenStoreKey) ?? ""
          let apnsError = defaults.string(forKey: self.apnsErrorStoreKey) ?? ""
          let voip = defaults.string(forKey: self.voipTokenStoreKey) ?? ""
          let lastPushkitIncomingAt =
            defaults.string(forKey: self.lastPushkitIncomingAtStoreKey) ?? ""
          let lastPushkitIncomingCallId =
            defaults.string(forKey: self.lastPushkitIncomingCallIdStoreKey) ?? ""
          let lastPushkitIncomingChannel =
            defaults.string(forKey: self.lastPushkitIncomingChannelStoreKey) ?? ""
          let lastPushkitIncomingCallkitId =
            defaults.string(forKey: self.lastPushkitIncomingCallkitIdStoreKey) ?? ""
          let lastPushkitStage =
            defaults.string(forKey: self.lastPushkitStageStoreKey) ?? ""
          let lastPushkitDetail =
            defaults.string(forKey: self.lastPushkitDetailStoreKey) ?? ""
          let lastPushkitPayloadType =
            defaults.string(forKey: self.lastPushkitPayloadTypeStoreKey) ?? ""
          let lastCallkitAcceptedAt =
            defaults.string(forKey: self.lastCallkitAcceptedAtStoreKey) ?? ""
          let lastCallkitAcceptedInviteId =
            defaults.string(forKey: self.lastCallkitAcceptedInviteIdStoreKey) ?? ""
          let lastCallkitAcceptedChannel =
            defaults.string(forKey: self.lastCallkitAcceptedChannelStoreKey) ?? ""
          let lastCallkitAcceptedCallkitId =
            defaults.string(forKey: self.lastCallkitAcceptedCallkitIdStoreKey) ?? ""
          let lastCallkitAcceptedFromName =
            defaults.string(forKey: self.lastCallkitAcceptedFromNameStoreKey) ?? ""
          let lastCallkitAcceptedFromUid =
            defaults.string(forKey: self.lastCallkitAcceptedFromUidStoreKey) ?? ""
          let lastCallkitAcceptedIsVideo =
            defaults.string(forKey: self.lastCallkitAcceptedIsVideoStoreKey) ?? ""
          let lastCallkitEvent =
            defaults.string(forKey: self.lastCallkitEventStoreKey) ?? ""
          let lastCallkitEventAt =
            defaults.string(forKey: self.lastCallkitEventAtStoreKey) ?? ""
          let lastCallkitEventCallkitId =
            defaults.string(forKey: self.lastCallkitEventCallkitIdStoreKey) ?? ""
          let lastCallkitEventInviteId =
            defaults.string(forKey: self.lastCallkitEventInviteIdStoreKey) ?? ""
          let lastCallkitEventChannel =
            defaults.string(forKey: self.lastCallkitEventChannelStoreKey) ?? ""
          result([
            "apnsToken": apns,
            "apnsTokenSuffix": self.tokenSuffix(apns),
            "apnsError": apnsError,
            "voipToken": voip,
            "voipTokenSuffix": self.tokenSuffix(voip),
            "lastPushkitIncomingAt": lastPushkitIncomingAt,
            "lastPushkitIncomingCallId": lastPushkitIncomingCallId,
            "lastPushkitIncomingChannel": lastPushkitIncomingChannel,
            "lastPushkitIncomingCallkitId": lastPushkitIncomingCallkitId,
            "lastPushkitStage": lastPushkitStage,
            "lastPushkitDetail": lastPushkitDetail,
            "lastPushkitPayloadType": lastPushkitPayloadType,
            "lastCallkitAcceptedAt": lastCallkitAcceptedAt,
            "lastCallkitAcceptedInviteId": lastCallkitAcceptedInviteId,
            "lastCallkitAcceptedChannel": lastCallkitAcceptedChannel,
            "lastCallkitAcceptedCallkitId": lastCallkitAcceptedCallkitId,
            "lastCallkitAcceptedFromName": lastCallkitAcceptedFromName,
            "lastCallkitAcceptedFromUid": lastCallkitAcceptedFromUid,
            "lastCallkitAcceptedIsVideo": lastCallkitAcceptedIsVideo,
            "lastCallkitEvent": lastCallkitEvent,
            "lastCallkitEventAt": lastCallkitEventAt,
            "lastCallkitEventCallkitId": lastCallkitEventCallkitId,
            "lastCallkitEventInviteId": lastCallkitEventInviteId,
            "lastCallkitEventChannel": lastCallkitEventChannel,
          ])
          return
        }

        if call.method == "clearStoredAcceptedCall" {
          self.clearStoredAcceptedCall()
          result(true)
          return
        }

        if call.method == "markCallkitInviteState" {
          guard let args = call.arguments as? [String: Any] else {
            result(false)
            return
          }
          let inviteId = ((args["inviteId"] as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
          let channel = ((args["channel"] as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
          let state = ((args["state"] as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
          let callkitId = self.normalizedCallkitId(
            raw: inviteId.isEmpty ? nil : inviteId,
            fallback: channel
          )
          self.markCallkitPresentationState(callkitId: callkitId, state: state)
          result(true)
          return
        }

        if call.method == "refreshPushRegistrations" {
          DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
            self.voipRegistry?.desiredPushTypes = [.voIP]
          }
          result(true)
          return
        }

        if call.method == "getApplicationState" {
          let state = UIApplication.shared.applicationState
          switch state {
          case .active:
            result("active")
          case .inactive:
            result("inactive")
          case .background:
            result("background")
          @unknown default:
            result("unknown")
          }
          return
        }

        result(FlutterMethodNotImplemented)
      }
    }

    // Keep a strong reference; PushKit callbacks can stop if registry is deallocated.
    let registry = PKPushRegistry(queue: DispatchQueue.main)
    registry.delegate = self
    registry.desiredPushTypes = [.voIP]
    voipRegistry = registry

    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    let type = (userInfo["type"] as? String) ?? ""
    let action = (userInfo["action"] as? String) ?? ""

    if type == "call_invite" || action == "incoming_call" {
      completionHandler([])
      return
    }

    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    let type = (userInfo["type"] as? String) ?? ""
    if type == "call_invite" {
      let inviteId = ((userInfo["inviteId"] as? String) ?? (userInfo["callId"] as? String) ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      let channel = ((userInfo["channel"] as? String) ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      let fromName = ((userInfo["fromName"] as? String) ?? "Caller")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      let fromUid = ((userInfo["fromUid"] as? String) ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      let isVideoRaw = "\((userInfo["isVideo"] as? String) ?? (userInfo["isVideo"] as? Bool == true ? "true" : "false"))"
      let isVideo = isVideoRaw.lowercased() == "true"
      let callkitId = normalizedCallkitId(
        raw: userInfo["callkitId"] as? String,
        fallback: inviteId.isEmpty ? channel : inviteId
      )
      let actionId = response.actionIdentifier

      if actionId == "DECLINE_CALL" {
        storeCallkitEvent(
          "decline",
          inviteId: inviteId,
          callkitId: callkitId,
          channel: channel
        )
        if !inviteId.isEmpty {
          syncInviteStatus(inviteId: inviteId, status: "declined", additional: [
            "declinedBy": Auth.auth().currentUser?.uid ?? "",
          ])
        }
        storePushkitState(
          "incoming_fallback_decline_received",
          payloadType: "call_invite",
          detail: "identifier_present=true"
        )
        completionHandler()
        return
      }

      if actionId == UNNotificationDismissActionIdentifier {
        storePushkitState(
          "incoming_fallback_dismissed",
          payloadType: "call_invite",
          detail: "identifier_present=true"
        )
        completionHandler()
        return
      }

      storeAcceptedCallData(
        inviteId: inviteId,
        channel: channel,
        callkitId: callkitId,
        fromName: fromName.isEmpty ? "Caller" : fromName,
        fromUid: fromUid,
        isVideo: isVideo
      )
      storeCallkitEvent(
        "accept",
        inviteId: inviteId,
        callkitId: callkitId,
        channel: channel
      )
      if !inviteId.isEmpty {
        syncInviteStatus(inviteId: inviteId, status: "accepted", additional: [
          "acceptedBy": Auth.auth().currentUser?.uid ?? "",
        ])
      }
      storePushkitState(
        "incoming_fallback_accept_received",
        payloadType: "call_invite",
        detail: "identifier_present=true action_present=\(!actionId.isEmpty)"
      )
      completionHandler()
      return
    }

    super.userNotificationCenter(
      center,
      didReceive: response,
      withCompletionHandler: completionHandler
    )
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Foundation.Data
  ) {
    Messaging.messaging().setAPNSToken(deviceToken, type: .unknown)
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    let defaults = UserDefaults.standard
    defaults.set(token, forKey: apnsTokenStoreKey)
    defaults.removeObject(forKey: apnsErrorStoreKey)
    NSLog("Helperly APNS token updated")
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("Helperly APNS registration failed: %@", error.localizedDescription)
    let defaults = UserDefaults.standard
    defaults.removeObject(forKey: apnsTokenStoreKey)
    defaults.set(error.localizedDescription, forKey: apnsErrorStoreKey)
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  private func tokenSuffix(_ token: String) -> String {
    let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      return ""
    }
    return String(trimmed.suffix(12))
  }

  private func normalizedCallkitId(raw rawValue: String?, fallback fallbackValue: String = "") -> String {
    let trimmedRaw = (rawValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if let uuid = UUID(uuidString: trimmedRaw) {
      return uuid.uuidString.lowercased()
    }

    let trimmedFallback = fallbackValue.trimmingCharacters(in: .whitespacesAndNewlines)
    if let uuid = UUID(uuidString: trimmedFallback) {
      return uuid.uuidString.lowercased()
    }

    let source = trimmedRaw.isEmpty
      ? (trimmedFallback.isEmpty ? "0" : trimmedFallback)
      : trimmedRaw
    let baseHex = source.utf8.map { String(format: "%02x", $0) }.joined()
    var hex = baseHex
    while hex.count < 32 {
      hex.append(baseHex)
    }
    hex = String(hex.prefix(32))

    var characters = Array(hex)
    characters[12] = "4"
    characters[16] = "8"
    let normalizedHex = String(characters)

    return [
      String(normalizedHex.prefix(8)),
      String(normalizedHex.dropFirst(8).prefix(4)),
      String(normalizedHex.dropFirst(12).prefix(4)),
      String(normalizedHex.dropFirst(16).prefix(4)),
      String(normalizedHex.dropFirst(20).prefix(12)),
    ].joined(separator: "-")
  }

  private func storeLastPushkitIncoming(
    rawCallId: String,
    channel: String,
    callkitId: String
  ) {
    let formatter = ISO8601DateFormatter()
    let defaults = UserDefaults.standard
    defaults.set(formatter.string(from: Date()), forKey: lastPushkitIncomingAtStoreKey)
    defaults.set(rawCallId, forKey: lastPushkitIncomingCallIdStoreKey)
    defaults.set(channel, forKey: lastPushkitIncomingChannelStoreKey)
    defaults.set(callkitId, forKey: lastPushkitIncomingCallkitIdStoreKey)
  }

  private func storePushkitState(
    _ stage: String,
    payloadType: String = "",
    detail: String = ""
  ) {
    let defaults = UserDefaults.standard
    defaults.set(stage, forKey: lastPushkitStageStoreKey)
    defaults.set(payloadType, forKey: lastPushkitPayloadTypeStoreKey)
    defaults.set(detail, forKey: lastPushkitDetailStoreKey)
  }

  private func callkitPresentationLedger() -> [String: [String: Any]] {
    return (UserDefaults.standard.dictionary(forKey: callkitPresentationLedgerStoreKey)
      as? [String: [String: Any]]) ?? [:]
  }

  private func writeCallkitPresentationLedger(_ ledger: [String: [String: Any]]) {
    UserDefaults.standard.set(ledger, forKey: callkitPresentationLedgerStoreKey)
  }

  private func pruneCallkitPresentationLedger(_ ledger: [String: [String: Any]])
    -> [String: [String: Any]]
  {
    let now = Date().timeIntervalSince1970
    return ledger.filter { _, value in
      let timestamp = value["timestamp"] as? TimeInterval ?? 0
      return timestamp > 0 && now - timestamp <= callkitPresentationLedgerTtlSeconds
    }
  }

  private func markCallkitPresentationState(callkitId: String, state: String) {
    let key = callkitId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let normalizedState = state.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !key.isEmpty, ["presented", "accepted", "active", "terminal"].contains(normalizedState)
    else { return }
    var ledger = pruneCallkitPresentationLedger(callkitPresentationLedger())
    ledger[key] = [
      "state": normalizedState,
      "timestamp": Date().timeIntervalSince1970,
    ]
    writeCallkitPresentationLedger(ledger)
  }

  private func callkitPresentationState(callkitId: String) -> String {
    let key = callkitId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !key.isEmpty else { return "" }
    let ledger = pruneCallkitPresentationLedger(callkitPresentationLedger())
    writeCallkitPresentationLedger(ledger)
    return (ledger[key]?["state"] as? String) ?? ""
  }

  private func activeCallkitContains(callkitId: String) -> Bool {
    let expected = callkitId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !expected.isEmpty else { return false }
    let activeCalls = SwiftFlutterCallkitIncomingPlugin.sharedInstance?.activeCalls() ?? []
    return activeCalls.contains { raw in
      let id = ((raw["id"] as? String) ?? (raw["uuid"] as? String) ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
      let extra = raw["extra"] as? [String: Any]
      let extraId = ((extra?["callkitId"] as? String) ?? (extra?["id"] as? String) ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
      return id == expected || extraId == expected
    }
  }

  private func ensureFirebaseConfigured() {
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
  }

  private func inviteIdFromCall(_ call: Call?) -> String {
    let extra = call?.data.extra as? [String: Any]
    let inviteId = (extra?["inviteId"] as? String) ?? ""
    if !inviteId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return inviteId
    }
    let callId = (extra?["callId"] as? String) ?? ""
    if !callId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return callId
    }
    return call?.data.uuid ?? ""
  }

  private func syncInviteStatus(
    inviteId: String,
    status: String,
    additional: [String: Any] = [:]
  ) {
    let trimmedInviteId = inviteId.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedStatus = status.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedInviteId.isEmpty, !trimmedStatus.isEmpty else { return }

    ensureFirebaseConfigured()
    var payload: [String: Any] = [
      "status": trimmedStatus,
      "\(trimmedStatus)At": FieldValue.serverTimestamp(),
      "nativeStatusSource": "ios_callkit",
    ]
    for (key, value) in additional {
      payload[key] = value
    }

    Firestore.firestore().runTransaction({ transaction, errorPointer -> Any? in
      let ref = Firestore.firestore().collection("callInvites").document(trimmedInviteId)
      let snapshot: DocumentSnapshot
      do {
        snapshot = try transaction.getDocument(ref)
      } catch let error as NSError {
        errorPointer?.pointee = error
        return nil
      }
      guard snapshot.exists else { return false }
      let data = snapshot.data() ?? [:]
      let currentStatus = ((data["status"] as? String) ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
      let terminalStatuses: Set<String> = ["declined", "missed", "cancelled", "ended", "failed"]
      if terminalStatuses.contains(currentStatus) {
        return false
      }
      let allowed: Bool
      switch trimmedStatus {
      case "accepted":
        allowed = currentStatus == "ringing"
      case "declined", "missed":
        allowed = currentStatus == "ringing"
      case "ended":
        allowed = ["ringing", "accepted", "joining", "connected"].contains(currentStatus)
      default:
        allowed = false
      }
      if !allowed { return false }
      transaction.setData(payload, forDocument: ref, merge: true)
      return true
    }) { result, error in
        if let error {
          self.storePushkitState(
            "invite_status_sync_error",
            payloadType: trimmedStatus,
            detail: "identifier_present=true error=true"
          )
          NSLog(
            "Helperly CallKit invite status sync failed status=%@ error=true",
            trimmedStatus,
            ""
          )
          return
        }
        let updated = (result as? Bool) == true
        self.storePushkitState(
          updated ? "invite_status_synced" : "invite_status_sync_blocked",
          payloadType: trimmedStatus,
          detail: "identifier_present=true"
        )
        NSLog(
          "Helperly CallKit invite status sync completed status=%@ updated=%@",
          trimmedStatus,
          updated ? "true" : "false"
        )
      }
  }

  private func shouldSyncInviteStatusFromNative() -> Bool {
    return UIApplication.shared.applicationState == .background
  }

  private func shouldPresentIncomingCallkitFromNative() -> Bool {
    // Every VoIP push representing a real call must be reported to CallKit
    // promptly. Skipping CallKit while the app is active/inactive can make iOS
    // throttle later PushKit deliveries, which appears as progressively slower
    // incoming call prompts after repeated calls.
    return true
  }

  private func appStateLabel(_ state: UIApplication.State) -> String {
    switch state {
    case .active:
      return "active"
    case .inactive:
      return "inactive"
    case .background:
      return "background"
    @unknown default:
      return "unknown"
    }
  }

  private func notifyFlutterOfForegroundVoip(
    method: String,
    payload: [String: Any]
  ) {
    DispatchQueue.main.async {
      self.pushTokenChannel?.invokeMethod(method, arguments: payload)
    }
  }

  private func showIncomingFallbackNotification(
    callkitId: String,
    channel: String,
    fromName: String,
    fromUid: String,
    isVideo: Bool,
    inviteId: String
  ) {
    let content = UNMutableNotificationContent()
    content.title = isVideo ? "Incoming Video Call" : "Incoming Audio Call"
    content.body = "From \(fromName)"
    content.sound = .default
    content.categoryIdentifier = "INCOMING_CALL"
    content.userInfo = [
      "type": "call_invite",
      "channel": channel,
      "isVideo": isVideo ? "true" : "false",
      "fromName": fromName,
      "fromUid": fromUid,
      "callId": inviteId,
      "inviteId": inviteId,
      "callkitId": callkitId,
    ]

    let request = UNNotificationRequest(
      identifier: "callkit_fallback_\(callkitId)",
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request)
    storePushkitState(
      "incoming_fallback_notification_scheduled",
      payloadType: "call_invite",
      detail: "identifier_present=true"
    )
  }

  private func endDisplayedCall(
    callkitId: String,
    rawCallId: String,
    channel: String,
    payloadType: String,
    detail: String = ""
  ) {
    let trimmedCallkitId = callkitId.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmedCallkitId.isEmpty { return }
    markCallkitPresentationState(callkitId: trimmedCallkitId, state: "terminal")

    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.saveEndCall(trimmedCallkitId, 2)
    let data = flutter_callkit_incoming.Data(
      id: trimmedCallkitId,
      nameCaller: "Helperly",
      handle: channel.isEmpty ? "Call ended" : channel,
      type: 0
    )
    data.extra = [
      "id": trimmedCallkitId,
      "callkitId": trimmedCallkitId,
      "callId": rawCallId,
      "inviteId": rawCallId,
      "channel": channel,
    ]
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endCall(data)
    clearStoredAcceptedCall()
    storePushkitState(
      "terminal_push_end_requested",
      payloadType: payloadType,
      detail: detail.isEmpty ? "identifier_present=true" : detail
    )
  }

  private func clearStoredAcceptedCall() {
    let defaults = UserDefaults.standard
    defaults.removeObject(forKey: lastCallkitAcceptedAtStoreKey)
    defaults.removeObject(forKey: lastCallkitAcceptedInviteIdStoreKey)
    defaults.removeObject(forKey: lastCallkitAcceptedChannelStoreKey)
    defaults.removeObject(forKey: lastCallkitAcceptedCallkitIdStoreKey)
    defaults.removeObject(forKey: lastCallkitAcceptedFromNameStoreKey)
    defaults.removeObject(forKey: lastCallkitAcceptedFromUidStoreKey)
    defaults.removeObject(forKey: lastCallkitAcceptedIsVideoStoreKey)
  }

  private func storeAcceptedCall(_ call: Call) {
    let extra = call.data.extra as? [String: Any]
    let isVideo: Bool
    if let rawIsVideo = extra?["isVideo"] {
      isVideo = "\(rawIsVideo)".lowercased() == "true"
    } else {
      isVideo = call.data.type > 0
    }
    storeAcceptedCallData(
      inviteId: (extra?["inviteId"] as? String) ?? "",
      channel: (extra?["channel"] as? String) ?? "",
      callkitId: call.data.uuid,
      fromName: (extra?["fromName"] as? String) ?? call.data.nameCaller,
      fromUid: (extra?["fromUid"] as? String) ?? "",
      isVideo: isVideo
    )
  }

  private func storeAcceptedCallData(
    inviteId: String,
    channel: String,
    callkitId: String,
    fromName: String,
    fromUid: String,
    isVideo: Bool
  ) {
    let formatter = ISO8601DateFormatter()
    let defaults = UserDefaults.standard
    defaults.set(formatter.string(from: Date()), forKey: lastCallkitAcceptedAtStoreKey)
    defaults.set(inviteId, forKey: lastCallkitAcceptedInviteIdStoreKey)
    defaults.set(channel, forKey: lastCallkitAcceptedChannelStoreKey)
    defaults.set(callkitId, forKey: lastCallkitAcceptedCallkitIdStoreKey)
    defaults.set(fromName, forKey: lastCallkitAcceptedFromNameStoreKey)
    defaults.set(fromUid, forKey: lastCallkitAcceptedFromUidStoreKey)
    defaults.set(isVideo ? "true" : "false", forKey: lastCallkitAcceptedIsVideoStoreKey)
  }

  private func storeCallkitEvent(_ event: String, call: Call?) {
    let formatter = ISO8601DateFormatter()
    let defaults = UserDefaults.standard
    let extra = call?.data.extra as? [String: Any]
    defaults.set(event, forKey: lastCallkitEventStoreKey)
    defaults.set(formatter.string(from: Date()), forKey: lastCallkitEventAtStoreKey)
    defaults.set(call?.data.uuid ?? "", forKey: lastCallkitEventCallkitIdStoreKey)
    defaults.set((extra?["inviteId"] as? String) ?? "", forKey: lastCallkitEventInviteIdStoreKey)
    defaults.set((extra?["channel"] as? String) ?? "", forKey: lastCallkitEventChannelStoreKey)
  }

  private func storeCallkitEvent(
    _ event: String,
    inviteId: String,
    callkitId: String,
    channel: String
  ) {
    let formatter = ISO8601DateFormatter()
    let defaults = UserDefaults.standard
    defaults.set(event, forKey: lastCallkitEventStoreKey)
    defaults.set(formatter.string(from: Date()), forKey: lastCallkitEventAtStoreKey)
    defaults.set(callkitId, forKey: lastCallkitEventCallkitIdStoreKey)
    defaults.set(inviteId, forKey: lastCallkitEventInviteIdStoreKey)
    defaults.set(channel, forKey: lastCallkitEventChannelStoreKey)
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didUpdate credentials: PKPushCredentials,
    for type: PKPushType
  ) {
    let deviceToken = credentials.token.map { String(format: "%02x", $0) }.joined()
    UserDefaults.standard.set(deviceToken, forKey: voipTokenStoreKey)
    NSLog("Helperly PushKit token updated")
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(deviceToken)
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didInvalidatePushTokenFor type: PKPushType
  ) {
    UserDefaults.standard.removeObject(forKey: voipTokenStoreKey)
    NSLog("Helperly PushKit token invalidated")
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType,
    completion: @escaping () -> Void
  ) {
    var didComplete = false
    let finish: () -> Void = {
      if didComplete { return }
      didComplete = true
      completion()
    }

    guard type == .voIP else {
      finish()
      return
    }

    let data = payload.dictionaryPayload
    let payloadType = ((data["type"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    let payloadStatus = ((data["status"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    let rawCallId = (data["callId"] as? String) ?? ""
    let fromName = (data["fromName"] as? String) ?? "Caller"
    let fromUid = (data["fromUid"] as? String) ?? ""
    let channel = (data["channel"] as? String) ?? ""
    let isVideoRaw = "\((data["isVideo"] as? String) ?? (data["isVideo"] as? Bool == true ? "true" : "false"))"
    let isVideo = isVideoRaw.lowercased() == "true"
    let callkitId = normalizedCallkitId(raw: rawCallId, fallback: channel)
    storeLastPushkitIncoming(rawCallId: rawCallId, channel: channel, callkitId: callkitId)
    storePushkitState(
      "incoming_received",
      payloadType: payloadType.isEmpty ? "call_invite" : payloadType,
      detail: "identifier_present=true"
    )
    NSLog(
      "Helperly PushKit incoming push type=%@ status=%@ identifier_present=true",
      payloadType,
      payloadStatus
    )

    if payloadType == "call_end" || payloadType == "call_cancel" ||
        payloadStatus == "ended" || payloadStatus == "declined" ||
        payloadStatus == "missed" || payloadStatus == "cancelled" ||
        payloadStatus == "failed" {
      markCallkitPresentationState(callkitId: callkitId, state: "terminal")
      endDisplayedCall(
        callkitId: callkitId,
        rawCallId: rawCallId,
        channel: channel,
        payloadType: payloadType.isEmpty ? payloadStatus : payloadType,
        detail: "status=\(payloadStatus) identifier_present=true"
      )
      finish()
      return
    }

    let presentationState = callkitPresentationState(callkitId: callkitId)
    if presentationState == "accepted" || presentationState == "active" ||
        presentationState == "terminal" {
      if presentationState == "terminal" {
        endDisplayedCall(
          callkitId: callkitId,
          rawCallId: rawCallId,
          channel: channel,
          payloadType: payloadType.isEmpty ? "call_invite" : payloadType,
          detail: "late_push_suppressed=true terminal=true identifier_present=true"
        )
      } else {
        storePushkitState(
          "late_push_suppressed",
          payloadType: payloadType.isEmpty ? "call_invite" : payloadType,
          detail: "late_push_suppressed=true identifier_present=true"
        )
      }
      NSLog("Helperly PushKit late incoming suppressed identifier_present=true")
      finish()
      return
    }

    if activeCallkitContains(callkitId: callkitId) {
      markCallkitPresentationState(callkitId: callkitId, state: "presented")
      storePushkitState(
        "duplicate_callkit_suppressed",
        payloadType: payloadType.isEmpty ? "call_invite" : payloadType,
        detail: "duplicate_callkit_suppressed=true identifier_present=true"
      )
      NSLog("Helperly PushKit duplicate CallKit suppressed identifier_present=true")
      finish()
      return
    }

    let callData = flutter_callkit_incoming.Data(
      id: callkitId,
      nameCaller: fromName,
      handle: fromName,
      type: isVideo ? 1 : 0
    )
    callData.appName = "Helperly"
    callData.iconName = "LaunchImage"
    callData.handleType = "generic"
    callData.supportsVideo = isVideo
    callData.supportsDTMF = false
    callData.supportsHolding = false
    callData.supportsGrouping = false
    callData.supportsUngrouping = false
    callData.configureAudioSession = true
    callData.audioSessionMode = "voiceChat"
    callData.audioSessionActive = true
    callData.isShowMissedCallNotification = false
    callData.extra = [
      "id": callkitId,
      "callkitId": callkitId,
      "callId": rawCallId,
      "inviteId": rawCallId,
      "channel": channel,
      "fromUid": fromUid,
      "fromName": fromName,
      "isVideo": isVideo ? "true" : "false",
    ]

    let appState = UIApplication.shared.applicationState
    if !shouldPresentIncomingCallkitFromNative() {
      let stateLabel = appStateLabel(appState)
      storePushkitState(
        "incoming_foreground_handoff",
        payloadType: payloadType.isEmpty ? "call_invite" : payloadType,
        detail: "state=\(stateLabel) identifier_present=true"
      )
      notifyFlutterOfForegroundVoip(
        method: "incomingVoipForeground",
        payload: [
          "type": payloadType.isEmpty ? "call_invite" : payloadType,
          "callId": rawCallId,
          "inviteId": rawCallId,
          "channel": channel,
          "fromName": fromName,
          "fromUid": fromUid,
          "isVideo": isVideo ? "true" : "false",
          "appState": stateLabel,
        ]
      )
      NSLog(
        "Helperly PushKit skipping native CallKit in foreground state=%@ identifier_present=true",
        stateLabel
      )
      finish()
      return
    }

    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(
      callData,
      fromPushKit: true
    )
    markCallkitPresentationState(callkitId: callkitId, state: "presented")
    storePushkitState(
      "incoming_report_requested",
      payloadType: payloadType.isEmpty ? "call_invite" : payloadType,
      detail: "identifier_present=true"
    )

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
      let activeCalls =
        SwiftFlutterCallkitIncomingPlugin.sharedInstance?.activeCalls() ?? []
      let hasCall = activeCalls.contains { raw in
        let id = ((raw["id"] as? String) ?? (raw["uuid"] as? String) ?? "")
          .lowercased()
        return id == callkitId.lowercased()
      }
      if hasCall {
        self.storePushkitState(
          "incoming_reported",
          payloadType: payloadType.isEmpty ? "call_invite" : payloadType,
          detail: "identifier_present=true"
        )
      } else {
        self.storePushkitState(
          "incoming_report_missing",
          payloadType: payloadType.isEmpty ? "call_invite" : payloadType,
          detail: "identifier_present=true"
        )
      }
    }

    // iOS can terminate the app if PushKit handling takes too long.
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
      finish()
    }
  }

  func onAccept(_ call: Call, _ action: CXAnswerCallAction) {
    storeAcceptedCall(call)
    storeCallkitEvent("accept", call: call)
    markCallkitPresentationState(callkitId: call.data.uuid, state: "accepted")
    let inviteId = inviteIdFromCall(call)
    if !inviteId.isEmpty && shouldSyncInviteStatusFromNative() {
      syncInviteStatus(inviteId: inviteId, status: "accepted", additional: [
        "acceptedBy": Auth.auth().currentUser?.uid ?? "",
      ])
    }
    NSLog("Helperly CallKit onAccept identifier_present=true")
    action.fulfill()
  }

  func onDecline(_ call: Call, _ action: CXEndCallAction) {
    storeCallkitEvent("decline", call: call)
    clearStoredAcceptedCall()
    markCallkitPresentationState(callkitId: call.data.uuid, state: "terminal")
    let inviteId = inviteIdFromCall(call)
    if !inviteId.isEmpty && shouldSyncInviteStatusFromNative() {
      syncInviteStatus(inviteId: inviteId, status: "declined", additional: [
        "declinedBy": Auth.auth().currentUser?.uid ?? "",
      ])
    }
    NSLog("Helperly CallKit onDecline identifier_present=true")
    action.fulfill()
  }

  func onEnd(_ call: Call, _ action: CXEndCallAction) {
    storeCallkitEvent("end", call: call)
    clearStoredAcceptedCall()
    markCallkitPresentationState(callkitId: call.data.uuid, state: "terminal")
    let inviteId = inviteIdFromCall(call)
    if !inviteId.isEmpty && shouldSyncInviteStatusFromNative() {
      syncInviteStatus(inviteId: inviteId, status: "ended", additional: [
        "endedBy": Auth.auth().currentUser?.uid ?? "",
      ])
    }
    NSLog("Helperly CallKit onEnd identifier_present=true")
    action.fulfill()
  }

  func onTimeOut(_ call: Call) {
    storeCallkitEvent("timeout", call: call)
    clearStoredAcceptedCall()
    markCallkitPresentationState(callkitId: call.data.uuid, state: "terminal")
    let inviteId = inviteIdFromCall(call)
    if !inviteId.isEmpty && shouldSyncInviteStatusFromNative() {
      syncInviteStatus(inviteId: inviteId, status: "missed")
    }
    NSLog("Helperly CallKit onTimeOut identifier_present=true")
  }

  func didActivateAudioSession(_ audioSession: AVAudioSession) {
    storeCallkitEvent("audio_activated", call: nil)
    NSLog("Helperly CallKit audio session activated")
  }

  func didDeactivateAudioSession(_ audioSession: AVAudioSession) {
    storeCallkitEvent("audio_deactivated", call: nil)
    NSLog("Helperly CallKit audio session deactivated")
  }
}
