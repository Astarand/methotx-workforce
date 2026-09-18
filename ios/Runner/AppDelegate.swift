import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    #if DEBUG
    print("[APNs Error] Failed to register for remote notifications: \(error.localizedDescription)")
    #endif
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  override func applicationDidEnterBackground(_ application: UIApplication) {
    // Obscure sensitive financial/employee PII in iOS App Switcher
    let blurEffect = UIBlurEffect(style: .extraLight)
    let blurView = UIVisualEffectView(effect: blurEffect)
    blurView.frame = window?.frame ?? .zero
    blurView.tag = 9999
    window?.addSubview(blurView)
  }

  override func applicationWillEnterForeground(_ application: UIApplication) {
    // Un-mask view upon returning to foreground
    window?.viewWithTag(9999)?.removeFromSuperview()
  }
}

