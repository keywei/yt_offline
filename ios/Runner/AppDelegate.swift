import AVFoundation
import Flutter
import Security
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// MethodChannel name shared with the Dart side (FullPlayer).
  private static let orientationChannelName = "yt_offline/orientation"
  /// Shared with the Dart `ShareIntake` service.
  private static let shareChannelName = "yt_offline/share"
  /// PiP channel. media_kit on iOS uses libmpv (CoreAudio + a custom
  /// surface) instead of AVPlayer, so the AVPictureInPictureController
  /// path doesn't apply. We answer the same channel but report
  /// `isSupported = false` and ignore `enter`.
  private static let pipChannelName = "yt_offline/pip"
  /// Reads the embedded provisioning profile's expiry so the Settings
  /// screen can warn the user before signing dies.
  private static let profileChannelName = "yt_offline/profile"

  /// URL captured from `application(_:open:)` before the engine attached.
  /// Cleared on `getInitial`.
  private var pendingShare: String?
  private var shareChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    configureAudioSession()
    registerAudioObservers()
    if let url = launchOptions?[.url] as? URL {
      pendingShare = url.absoluteString
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    let value = url.absoluteString
    // Engine may not be ready yet on a cold-from-URL launch; cache for
    // getInitial. When live, push through the channel.
    if shareChannel?.invokeMethod("onShare", arguments: value) == nil {
      pendingShare = value
    }
    return true
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: AppDelegate.orientationChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handleOrientationCall(call, result: result)
    }

    let share = FlutterMethodChannel(
      name: AppDelegate.shareChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    share.setMethodCallHandler { [weak self] call, result in
      guard call.method == "getInitial" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let v = self?.pendingShare
      self?.pendingShare = nil
      result(v)
    }
    shareChannel = share

    let pip = FlutterMethodChannel(
      name: AppDelegate.pipChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    pip.setMethodCallHandler { call, result in
      switch call.method {
      case "isSupported": result(false)
      case "enter": result(false)
      default: result(FlutterMethodNotImplemented)
      }
    }

    let profile = FlutterMethodChannel(
      name: AppDelegate.profileChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    profile.setMethodCallHandler { [weak self] call, result in
      self?.handleProfileCall(call, result: result)
    }
  }

  // MARK: - Provisioning profile inspection

  /// Reads `embedded.mobileprovision` (every signed .app ships one) and
  /// returns its ExpirationDate as an ISO-8601 string. The profile is a
  /// PKCS#7 signed blob wrapping a plist, so we use CMSDecoder to extract
  /// the payload before parsing.
  private func handleProfileCall(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard call.method == "expiry" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let date = readEmbeddedProfileExpiry() else {
      result(nil)
      return
    }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    result(formatter.string(from: date))
  }

  private func readEmbeddedProfileExpiry() -> Date? {
    guard
      let path = Bundle.main.path(
        forResource: "embedded",
        ofType: "mobileprovision"
      ),
      let data = try? Data(contentsOf: URL(fileURLWithPath: path))
    else {
      return nil
    }

    var decoder: CMSDecoder?
    guard CMSDecoderCreate(&decoder) == errSecSuccess, let d = decoder else {
      return nil
    }
    let updateStatus = data.withUnsafeBytes { bytes -> OSStatus in
      guard let base = bytes.baseAddress else { return errSecParam }
      return CMSDecoderUpdateMessage(d, base, data.count)
    }
    guard updateStatus == errSecSuccess else { return nil }
    guard CMSDecoderFinalizeMessage(d) == errSecSuccess else { return nil }

    var contentRef: CFData?
    guard
      CMSDecoderCopyContent(d, &contentRef) == errSecSuccess,
      let plistData = contentRef as Data?
    else {
      return nil
    }

    guard
      let plist = try? PropertyListSerialization.propertyList(
        from: plistData,
        options: [],
        format: nil
      ) as? [String: Any]
    else {
      return nil
    }
    return plist["ExpirationDate"] as? Date
  }

  // MARK: - Orientation forcing

  /// Dart → iOS handler. `call.arguments` is the string "portrait" or
  /// "landscape" (we don't bother with left/right — either side works).
  /// Forces the device to rotate to that orientation right away.
  private func handleOrientationCall(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard call.method == "force" else {
      result(FlutterMethodNotImplemented)
      return
    }
    let target = (call.arguments as? String) ?? ""
    let mask = orientationMask(for: target)

    if #available(iOS 16.0, *) {
      guard let scene = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first(where: { $0.activationState == .foregroundActive })
        ?? UIApplication.shared.connectedScenes
          .compactMap({ $0 as? UIWindowScene })
          .first
      else {
        result(nil)
        return
      }
      let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: mask)
      scene.requestGeometryUpdate(prefs) { error in
        NSLog("requestGeometryUpdate failed: \(error.localizedDescription)")
      }
      scene.windows.first?.rootViewController?
        .setNeedsUpdateOfSupportedInterfaceOrientations()
    } else {
      // iOS 15 and earlier: only path is the "orientation" KVC trick.
      let raw: Int
      switch target {
      case "portrait":
        raw = UIInterfaceOrientation.portrait.rawValue
      case "landscape":
        // Pick whichever side the user is already closer to; default left.
        raw = UIInterfaceOrientation.landscapeLeft.rawValue
      default:
        raw = UIInterfaceOrientation.unknown.rawValue
      }
      if raw != UIInterfaceOrientation.unknown.rawValue {
        UIDevice.current.setValue(raw, forKey: "orientation")
      }
    }
    result(nil)
  }

  private func orientationMask(for s: String) -> UIInterfaceOrientationMask {
    switch s {
    case "portrait": return .portrait
    case "landscape": return .landscape
    default: return .all
    }
  }

  // MARK: - Audio session

  private func configureAudioSession() {
    do {
      try AVAudioSession.sharedInstance().setCategory(
        .playback,
        mode: .default,
        options: []
      )
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      NSLog("AVAudioSession setup failed: \(error)")
    }
  }

  // libmpv's CoreAudio output keeps writing samples but doesn't always re-arm
  // the session when iOS deactivates it (route change, transient interruption,
  // even some scene transitions). Re-asserting setActive(true) on these events
  // makes audio recover instead of going silent while the player UI still says
  // it's playing.
  private func registerAudioObservers() {
    let center = NotificationCenter.default
    center.addObserver(
      self,
      selector: #selector(handleInterruption(_:)),
      name: AVAudioSession.interruptionNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(handleRouteChange(_:)),
      name: AVAudioSession.routeChangeNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(handleMediaServicesReset),
      name: AVAudioSession.mediaServicesWereResetNotification,
      object: nil
    )
  }

  @objc private func handleInterruption(_ note: Notification) {
    guard
      let info = note.userInfo,
      let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: typeRaw)
    else { return }
    if type == .ended {
      reactivateSession()
    }
  }

  @objc private func handleRouteChange(_ note: Notification) {
    reactivateSession()
  }

  @objc private func handleMediaServicesReset() {
    configureAudioSession()
  }

  private func reactivateSession() {
    do {
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      NSLog("AVAudioSession reactivate failed: \(error)")
    }
  }
}
