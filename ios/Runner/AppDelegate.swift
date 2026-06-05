import Flutter
import UIKit
import UserNotifications
import FirebaseMessaging
import GoogleMobileAds
import google_mobile_ads

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var chaputNativeAdFactory: ChaputNativeAdFactory?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    if let controller = window?.rootViewController as? FlutterViewController {
      let notificationsChannel = FlutterMethodChannel(
        name: "chaput/notifications",
        binaryMessenger: controller.binaryMessenger
      )
      notificationsChannel.setMethodCallHandler { call, result in
        guard call.method == "resetBadge" else {
          result(FlutterMethodNotImplemented)
          return
        }
        if #available(iOS 16.0, *) {
          UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
        } else {
          UIApplication.shared.applicationIconBadgeNumber = 0
        }
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        result(nil)
      }
    }
    let factory = ChaputNativeAdFactory()
    chaputNativeAdFactory = factory
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(self, factoryId: "chaputNative", nativeAdFactory: factory)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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

  override func applicationWillTerminate(_ application: UIApplication) {
    FLTGoogleMobileAdsPlugin.unregisterNativeAdFactory(self, factoryId: "chaputNative")
    chaputNativeAdFactory = nil
    super.applicationWillTerminate(application)
  }
}

class ChaputNativeAdView: NativeAdView {
  private var pendingNativeAd: NativeAd?
  private var didBindNativeAd = false

  func bindWhenReady(_ nativeAd: NativeAd) {
    pendingNativeAd = nativeAd
    setNeedsLayout()
    DispatchQueue.main.async { [weak self] in
      self?.setNeedsLayout()
      self?.layoutIfNeeded()
    }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    guard !didBindNativeAd, bounds.width > 0, bounds.height > 0, let pendingNativeAd else {
      return
    }
    layoutIfNeeded()
    nativeAd = pendingNativeAd
    self.pendingNativeAd = nil
    didBindNativeAd = true
  }
}

class ChaputNativeAdFactory: NSObject, FLTNativeAdFactory {
  func createNativeAd(_ nativeAd: NativeAd, customOptions: [AnyHashable : Any]? = nil) -> NativeAdView {
    let adView = ChaputNativeAdView()
    adView.backgroundColor = .black
    adView.layer.cornerRadius = 18
    adView.layer.masksToBounds = true
    adView.layer.borderWidth = 1
    adView.layer.borderColor = UIColor.white.withAlphaComponent(0.22).cgColor

    let sponsored = UILabel()
    sponsored.font = UIFont.systemFont(ofSize: 12, weight: .bold)
    sponsored.textColor = UIColor.white.withAlphaComponent(0.8)
    sponsored.text = "Sponsorlu"

    let headline = UILabel()
    headline.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
    headline.textColor = .white
    headline.numberOfLines = 2
    headline.lineBreakMode = .byTruncatingTail

    let body = UILabel()
    body.font = UIFont.systemFont(ofSize: 13, weight: .regular)
    body.textColor = UIColor.white.withAlphaComponent(0.85)
    body.numberOfLines = 1
    body.lineBreakMode = .byTruncatingTail

    let advertiser = UILabel()
    advertiser.font = UIFont.systemFont(ofSize: 12, weight: .medium)
    advertiser.textColor = UIColor.white.withAlphaComponent(0.72)
    advertiser.numberOfLines = 1
    advertiser.lineBreakMode = .byTruncatingTail

    let store = UILabel()
    store.font = UIFont.systemFont(ofSize: 12, weight: .medium)
    store.textColor = UIColor.white.withAlphaComponent(0.72)
    store.numberOfLines = 1
    store.lineBreakMode = .byTruncatingTail

    let price = UILabel()
    price.font = UIFont.systemFont(ofSize: 12, weight: .medium)
    price.textColor = UIColor.white.withAlphaComponent(0.72)
    price.numberOfLines = 1
    price.lineBreakMode = .byTruncatingTail

    let rating = UILabel()
    rating.font = UIFont.systemFont(ofSize: 12, weight: .medium)
    rating.textColor = UIColor.white.withAlphaComponent(0.72)
    rating.numberOfLines = 1
    rating.lineBreakMode = .byTruncatingTail

    let mediaView = MediaView()
    mediaView.backgroundColor = .black
    mediaView.clipsToBounds = true
    mediaView.layer.cornerRadius = 10

    let icon = UIImageView()
    icon.contentMode = .scaleAspectFill
    icon.clipsToBounds = true
    icon.layer.cornerRadius = 6

    let cta = UIButton(type: .system)
    cta.backgroundColor = .white
    cta.setTitleColor(.black, for: .normal)
    cta.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
    cta.layer.cornerRadius = 18
    cta.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
    cta.isUserInteractionEnabled = false

    let adChoices = AdChoicesView()
    adChoices.translatesAutoresizingMaskIntoConstraints = false

    let mediaContainer = UIView()
    mediaContainer.translatesAutoresizingMaskIntoConstraints = false
    mediaContainer.clipsToBounds = true
    mediaContainer.layer.cornerRadius = 10

    mediaView.translatesAutoresizingMaskIntoConstraints = false
    mediaContainer.addSubview(mediaView)
    adView.addSubview(adChoices)

    let metaRow = UIStackView(arrangedSubviews: [advertiser, store, price, rating])
    metaRow.spacing = 8
    metaRow.alignment = .center
    metaRow.distribution = .fill

    [headline, body, advertiser, store, price, rating].forEach {
      $0.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
      $0.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    let bottom = UIStackView(arrangedSubviews: [icon, cta])
    bottom.axis = .horizontal
    bottom.spacing = 10
    bottom.alignment = .center

    let container = UIStackView(arrangedSubviews: [mediaContainer, sponsored, headline, metaRow, body, bottom])
    container.axis = .vertical
    container.spacing = 8
    container.translatesAutoresizingMaskIntoConstraints = false

    adView.addSubview(container)

    NSLayoutConstraint.activate([
      container.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 14),
      container.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -14),
      container.topAnchor.constraint(equalTo: adView.topAnchor, constant: 14),
      container.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -14),
      mediaView.leadingAnchor.constraint(equalTo: mediaContainer.leadingAnchor),
      mediaView.trailingAnchor.constraint(equalTo: mediaContainer.trailingAnchor),
      mediaView.topAnchor.constraint(equalTo: mediaContainer.topAnchor),
      mediaView.bottomAnchor.constraint(equalTo: mediaContainer.bottomAnchor),
      adChoices.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -22),
      adChoices.topAnchor.constraint(equalTo: adView.topAnchor, constant: 22),
      adChoices.widthAnchor.constraint(greaterThanOrEqualToConstant: 24),
      adChoices.heightAnchor.constraint(greaterThanOrEqualToConstant: 24),
      icon.widthAnchor.constraint(equalToConstant: 36),
      icon.heightAnchor.constraint(equalToConstant: 36),
      cta.heightAnchor.constraint(equalToConstant: 36),
      mediaContainer.heightAnchor.constraint(equalToConstant: 260),
    ])

    adView.headlineView = headline
    adView.mediaView = mediaView
    adView.adChoicesView = adChoices

    headline.text = nativeAd.headline
    if let advertiserText = nativeAd.advertiser?.trimmingCharacters(in: .whitespacesAndNewlines), !advertiserText.isEmpty {
      advertiser.text = advertiserText
      advertiser.isHidden = false
      adView.advertiserView = advertiser
    } else {
      advertiser.isHidden = true
      adView.advertiserView = nil
    }
    if let bodyText = nativeAd.body?.trimmingCharacters(in: .whitespacesAndNewlines), !bodyText.isEmpty {
      body.text = bodyText
      body.isHidden = false
      adView.bodyView = body
    } else {
      body.isHidden = true
      adView.bodyView = nil
    }

    if let storeText = nativeAd.store?.trimmingCharacters(in: .whitespacesAndNewlines), !storeText.isEmpty {
      store.text = storeText
      store.isHidden = false
      adView.storeView = store
    } else {
      store.isHidden = true
      adView.storeView = nil
    }

    if let priceText = nativeAd.price?.trimmingCharacters(in: .whitespacesAndNewlines), !priceText.isEmpty {
      price.text = priceText
      price.isHidden = false
      adView.priceView = price
    } else {
      price.isHidden = true
      adView.priceView = nil
    }

    if let starRating = nativeAd.starRating {
      rating.text = "\(starRating)★"
      rating.isHidden = false
      adView.starRatingView = rating
    } else {
      rating.isHidden = true
      adView.starRatingView = nil
    }

    metaRow.isHidden = advertiser.isHidden && store.isHidden && price.isHidden && rating.isHidden

    if let iconImage = nativeAd.icon?.image {
      icon.image = iconImage
      icon.isHidden = false
      adView.iconView = icon
    } else {
      icon.isHidden = true
      adView.iconView = nil
    }

    if let ctaText = nativeAd.callToAction?.trimmingCharacters(in: .whitespacesAndNewlines), !ctaText.isEmpty {
      cta.setTitle(ctaText, for: .normal)
      cta.isHidden = false
      adView.callToActionView = cta
    } else {
      cta.isHidden = true
      adView.callToActionView = nil
    }

    mediaView.mediaContent = nativeAd.mediaContent
    mediaView.isHidden = false

    adView.bindWhenReady(nativeAd)
    return adView
  }
}
