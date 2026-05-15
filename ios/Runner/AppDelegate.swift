import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
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
  }

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
