import AdServices
import AppTrackingTransparency
import FBSDKCoreKit
import FirebaseMessaging
import Flutter
import TikTokBusinessSDK
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let notificationsChannelName = "chaput/notifications"
  private let attributionChannelName = "chaput/attribution"
  private var isTikTokConfigured = false
  private var isTrackingAuthorizationRequestInFlight = false
  private var reportedPurchaseEventIds = Set<String>()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    _ = ApplicationDelegate.shared.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
    configureTikTokBusinessSdkIfConfigured()
    applyTrackingAuthorizationStatus(currentTrackingAuthorizationStatus())
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    registerNotificationsChannel()
    registerAttributionChannel()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    let handledByMeta = ApplicationDelegate.shared.application(app, open: url, options: options)
    let handledByFlutter = super.application(app, open: url, options: options)
    return handledByMeta || handledByFlutter
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

  private func registerAttributionChannel() {
    let messenger: FlutterBinaryMessenger?
    if let registrar = registrar(forPlugin: "ChaputAttribution") {
      messenger = registrar.messenger()
    } else if let controller = window?.rootViewController as? FlutterViewController {
      messenger = controller.binaryMessenger
    } else {
      messenger = nil
    }
    guard let messenger = messenger else {
      return
    }

    let attributionChannel = FlutterMethodChannel(
      name: attributionChannelName,
      binaryMessenger: messenger
    )
    attributionChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      switch call.method {
      case "requestTrackingAuthorization":
        self.requestTrackingAuthorization(result)
      case "appleSearchAdsToken":
        self.appleSearchAdsToken(result)
      case "trackEvent":
        self.trackAttributionEvent(call.arguments, result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func configureTikTokBusinessSdkIfConfigured() {
    guard
      let accessToken = Bundle.main.object(
        forInfoDictionaryKey: "TikTokAppEventsAccessToken"
      ) as? String,
      !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      let businessAppId = Bundle.main.object(
        forInfoDictionaryKey: "TikTokBusinessAppID"
      ) as? String,
      !businessAppId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      let config = TikTokConfig(
        accessToken: accessToken,
        appId: businessAppId,
        tiktokAppId: "7663786815312216084"
      )
    else {
      return
    }

    config.trackingEnabled = isTrackingAuthorized(currentTrackingAuthorizationStatus())
    #if DEBUG
    config.enableDebugMode()
    #endif
    TikTokBusiness.initializeSdk(config)
    isTikTokConfigured = true
  }

  private func currentTrackingAuthorizationStatus() -> ATTrackingManager.AuthorizationStatus {
    if #available(iOS 14, *) {
      return ATTrackingManager.trackingAuthorizationStatus
    }
    return .denied
  }

  private func isTrackingAuthorized(_ status: ATTrackingManager.AuthorizationStatus) -> Bool {
    status == .authorized
  }

  private func applyTrackingAuthorizationStatus(_ status: ATTrackingManager.AuthorizationStatus) {
    let isAuthorized = isTrackingAuthorized(status)
    Settings.shared.isAdvertiserIDCollectionEnabled = isAuthorized
    if isTikTokConfigured {
      TikTokBusiness.setTrackingEnabled(isAuthorized)
    }
  }

  private func requestTrackingAuthorization(_ result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard #available(iOS 14, *) else {
        result(-1)
        return
      }

      let currentStatus = ATTrackingManager.trackingAuthorizationStatus
      guard currentStatus == .notDetermined, !self.isTrackingAuthorizationRequestInFlight else {
        self.applyTrackingAuthorizationStatus(currentStatus)
        result(currentStatus.rawValue)
        return
      }

      self.isTrackingAuthorizationRequestInFlight = true
      ATTrackingManager.requestTrackingAuthorization { status in
        DispatchQueue.main.async {
          self.isTrackingAuthorizationRequestInFlight = false
          self.applyTrackingAuthorizationStatus(status)
          result(status.rawValue)
        }
      }
    }
  }

  private func appleSearchAdsToken(_ result: @escaping FlutterResult) {
    guard #available(iOS 14.3, *) else {
      result(nil)
      return
    }

    do {
      result(try AAAttribution.attributionToken())
    } catch {
      result(nil)
    }
  }

  private func trackAttributionEvent(_ arguments: Any?, _ result: @escaping FlutterResult) {
    guard
      let event = arguments as? [String: Any],
      let eventName = event["name"] as? String
    else {
      result(FlutterError(code: "invalid_event", message: "Missing event name", details: nil))
      return
    }

    switch eventName {
    case login:
      AppEvents.shared.logEvent(
          AppEvents.Name("user_login"),
          parameters: [
            AppEvents.ParameterName("login_method"): "email"
          ]
        )

        if isTikTokConfigured {
            TikTokBusiness.trackTTEvent(
              TikTokBaseEvent(eventName: TTEventName.login.rawValue)
            )
          }
    case "signup":
      AppEvents.shared.logEvent(.completedRegistration)
      if isTikTokConfigured {
        TikTokBusiness.trackTTEvent(
          TikTokBaseEvent(eventName: TTEventName.registration.rawValue)
        )
      }
    case "purchase":
      trackVerifiedPurchaseEvent(event)
    default:
      break
    }
    result(nil)
  }

  private func trackVerifiedPurchaseEvent(_ event: [String: Any]) {
    guard
      let transactionId = trimmedString(event["transactionId"]),
      let productId = trimmedString(event["productId"])
    else {
      return
    }
    guard !reportedPurchaseEventIds.contains(transactionId) else {
      return
    }
    reportedPurchaseEventIds.insert(transactionId)

    let currency = trimmedString(event["currency"])
    let value = doubleValue(event["value"])
    let parameters: [AppEvents.ParameterName: Any] = [
      .transactionID: transactionId,
      .contentID: productId,
    ]

    if let currency = currency, let value = value {
      AppEvents.shared.logPurchase(
        amount: value,
        currency: currency,
        parameters: parameters
      )
    } else {
      AppEvents.shared.logEvent(.purchased, parameters: parameters)
    }

    guard isTikTokConfigured else {
      return
    }
    let purchaseEvent = TikTokPurchaseEvent(eventId: transactionId)
    purchaseEvent.setContentId(productId)
    if let currency = tiktokCurrency(currency) {
      purchaseEvent.setCurrency(currency)
    }
    if let value = value {
      purchaseEvent.setValue(String(value))
    }
    TikTokBusiness.trackTTEvent(purchaseEvent)
  }

  private func trimmedString(_ value: Any?) -> String? {
    guard let text = value as? String else {
      return nil
    }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  private func doubleValue(_ value: Any?) -> Double? {
    if let number = value as? NSNumber {
      return number.doubleValue
    }
    if let double = value as? Double {
      return double
    }
    if let text = trimmedString(value) {
      return Double(text)
    }
    return nil
  }

  private func tiktokCurrency(_ code: String?) -> TTCurrency? {
    switch code?.uppercased() {
    case "AED": return TTCurrency.AED
    case "ARS": return TTCurrency.ARS
    case "AUD": return TTCurrency.AUD
    case "BDT": return TTCurrency.BDT
    case "BGN": return TTCurrency.BGN
    case "BHD": return TTCurrency.BHD
    case "BIF": return TTCurrency.BIF
    case "BOB": return TTCurrency.BOB
    case "BRL": return TTCurrency.BRL
    case "CAD": return TTCurrency.CAD
    case "CHF": return TTCurrency.CHF
    case "CLP": return TTCurrency.CLP
    case "CNY": return TTCurrency.CNY
    case "COP": return TTCurrency.COP
    case "CRC": return TTCurrency.CRC
    case "CZK": return TTCurrency.CZK
    case "DKK": return TTCurrency.DKK
    case "DZD": return TTCurrency.DZD
    case "EGP": return TTCurrency.EGP
    case "EUR": return TTCurrency.EUR
    case "GBP": return TTCurrency.GBP
    case "GTQ": return TTCurrency.GTQ
    case "HKD": return TTCurrency.HKD
    case "HNL": return TTCurrency.HNL
    case "HUF": return TTCurrency.HUF
    case "IDR": return TTCurrency.IDR
    case "ILS": return TTCurrency.ILS
    case "INR": return TTCurrency.INR
    case "IQD": return TTCurrency.IQD
    case "ISK": return TTCurrency.ISK
    case "JOD": return TTCurrency.JOD
    case "JPY": return TTCurrency.JPY
    case "KES": return TTCurrency.KES
    case "KHR": return TTCurrency.KHR
    case "KRW": return TTCurrency.KRW
    case "KWD": return TTCurrency.KWD
    case "KZT": return TTCurrency.KZT
    case "LBP": return TTCurrency.LBP
    case "MAD": return TTCurrency.MAD
    case "MOP": return TTCurrency.MOP
    case "MXN": return TTCurrency.MXN
    case "MYR": return TTCurrency.MYR
    case "NGN": return TTCurrency.NGN
    case "NIO": return TTCurrency.NIO
    case "NOK": return TTCurrency.NOK
    case "NZD": return TTCurrency.NZD
    case "OMR": return TTCurrency.OMR
    case "PEN": return TTCurrency.PEN
    case "PHP": return TTCurrency.PHP
    case "PKR": return TTCurrency.PKR
    case "PLN": return TTCurrency.PLN
    case "PYG": return TTCurrency.PYG
    case "QAR": return TTCurrency.QAR
    case "RON": return TTCurrency.RON
    case "RUB": return TTCurrency.RUB
    case "SAR": return TTCurrency.SAR
    case "SEK": return TTCurrency.SEK
    case "SGD": return TTCurrency.SGD
    case "THB": return TTCurrency.THB
    case "TRY": return TTCurrency.TRY
    case "TWD": return TTCurrency.TWD
    case "TZS": return TTCurrency.TZS
    case "UAH": return TTCurrency.UAH
    case "USD": return TTCurrency.USD
    case "VES": return TTCurrency.VES
    case "VND": return TTCurrency.VND
    case "ZAR": return TTCurrency.ZAR
    default: return nil
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
