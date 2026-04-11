import Flutter
import UIKit
import PushKit
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
  private var voipRegistry: PKPushRegistry?

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

        if call.method == "refreshPushRegistrations" {
          DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
            self.voipRegistry?.desiredPushTypes = [.voIP]
          }
          result(true)
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

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Foundation.Data
  ) {
    Messaging.messaging().setAPNSToken(deviceToken, type: .unknown)
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    let defaults = UserDefaults.standard
    defaults.set(token, forKey: apnsTokenStoreKey)
    defaults.removeObject(forKey: apnsErrorStoreKey)
    NSLog("Helperly APNS token updated suffix=%@", tokenSuffix(token))
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
    let formatter = ISO8601DateFormatter()
    let defaults = UserDefaults.standard
    let extra = call.data.extra as? [String: Any]
    defaults.set(formatter.string(from: Date()), forKey: lastCallkitAcceptedAtStoreKey)
    defaults.set((extra?["inviteId"] as? String) ?? "", forKey: lastCallkitAcceptedInviteIdStoreKey)
    defaults.set((extra?["channel"] as? String) ?? "", forKey: lastCallkitAcceptedChannelStoreKey)
    defaults.set(call.data.uuid, forKey: lastCallkitAcceptedCallkitIdStoreKey)
    defaults.set((extra?["fromName"] as? String) ?? call.data.nameCaller, forKey: lastCallkitAcceptedFromNameStoreKey)
    defaults.set((extra?["fromUid"] as? String) ?? "", forKey: lastCallkitAcceptedFromUidStoreKey)
    if let isVideo = extra?["isVideo"] {
      defaults.set("\(isVideo)", forKey: lastCallkitAcceptedIsVideoStoreKey)
    } else {
      defaults.set(call.data.type > 0 ? "true" : "false", forKey: lastCallkitAcceptedIsVideoStoreKey)
    }
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

  func pushRegistry(
    _ registry: PKPushRegistry,
    didUpdate credentials: PKPushCredentials,
    for type: PKPushType
  ) {
    let deviceToken = credentials.token.map { String(format: "%02x", $0) }.joined()
    UserDefaults.standard.set(deviceToken, forKey: voipTokenStoreKey)
    let tokenSuffix = String(deviceToken.suffix(12))
    NSLog("Helperly PushKit token updated suffix=%@", tokenSuffix)
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
    let rawCallId = (data["callId"] as? String) ?? ""
    let fromName = (data["fromName"] as? String) ?? "Caller"
    let fromUid = (data["fromUid"] as? String) ?? ""
    let channel = (data["channel"] as? String) ?? ""
    let isVideoRaw = "\((data["isVideo"] as? String) ?? (data["isVideo"] as? Bool == true ? "true" : "false"))"
    let isVideo = isVideoRaw.lowercased() == "true"
    let callkitId = normalizedCallkitId(raw: rawCallId, fallback: channel)
    storeLastPushkitIncoming(rawCallId: rawCallId, channel: channel, callkitId: callkitId)
    NSLog(
      "Helperly PushKit incoming push callId=%@ channel=%@ callkitId=%@",
      rawCallId,
      channel,
      callkitId
    )

    if UIApplication.shared.applicationState == .active {
      NSLog(
        "Helperly PushKit foreground skip CallKit callId=%@ channel=%@",
        rawCallId,
        channel
      )
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

    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(
      callData,
      fromPushKit: true
    ) {
      finish()
    }

    // iOS can terminate the app if PushKit handling takes too long.
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
      finish()
    }
  }

  func onAccept(_ call: Call, _ action: CXAnswerCallAction) {
    storeAcceptedCall(call)
    storeCallkitEvent("accept", call: call)
    NSLog("Helperly CallKit onAccept callkitId=%@", call.data.uuid)
    action.fulfill()
  }

  func onDecline(_ call: Call, _ action: CXEndCallAction) {
    storeCallkitEvent("decline", call: call)
    NSLog("Helperly CallKit onDecline callkitId=%@", call.data.uuid)
    action.fulfill()
  }

  func onEnd(_ call: Call, _ action: CXEndCallAction) {
    storeCallkitEvent("end", call: call)
    NSLog("Helperly CallKit onEnd callkitId=%@", call.data.uuid)
    action.fulfill()
  }

  func onTimeOut(_ call: Call) {
    storeCallkitEvent("timeout", call: call)
    NSLog("Helperly CallKit onTimeOut callkitId=%@", call.data.uuid)
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
