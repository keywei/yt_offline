import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// MethodChannel name shared with the Dart side (FullPlayer).
  private static let orientationChannelName = "yt_offline/orientation"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    configureAudioSession()
    registerAudioObservers()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: AppDelegate.orientationChannelName,
      binaryMessenger: engineBridge.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handleOrientationCall(call, result: result)
    }
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
