import Flutter
import UIKit
import UserNotifications
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let notificationsChannelName = "chaput/notifications"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    registerNotificationsChannel()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func registerNotificationsChannel() {
    let messenger: FlutterBinaryMessenger?
    if let registrar = registrar(forPlugin: "ChaputNotifications") {
      messenger = registrar.messenger()
    } else if let controller = window?.rootViewController as? FlutterViewController {
      messenger = controller.binaryMessenger
    } else {
      messenger = nil
    }
    guard let messenger = messenger else {
      return
    }
    let notificationsChannel = FlutterMethodChannel(
      name: notificationsChannelName,
      binaryMessenger: messenger
    )
    notificationsChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "resetBadge" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let self = self else {
        result(nil)
        return
      }
      self.resetNotificationBadge(result)
    }
  }

  private func resetNotificationBadge(_ result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      UNUserNotificationCenter.current().removeAllDeliveredNotifications()
      UIApplication.shared.applicationIconBadgeNumber = 0
      if #available(iOS 16.0, *) {
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
          if let error = error {
            result(FlutterError(
              code: "badge_reset_failed",
              message: error.localizedDescription,
              details: nil
            ))
            return
          }
          result(nil)
        }
      } else {
        result(nil)
      }
    }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    #if DEBUG
    Messaging.messaging().setAPNSToken(deviceToken, type: .sandbox)
    #else
    Messaging.messaging().setAPNSToken(deviceToken, type: .prod)
    #endif
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
}
