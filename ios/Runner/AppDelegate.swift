import Flutter
import UIKit
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
    let factory = ChaputNativeAdFactory()
    chaputNativeAdFactory = factory
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(self, factoryId: "chaputNative", nativeAdFactory: factory)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationWillTerminate(_ application: UIApplication) {
    FLTGoogleMobileAdsPlugin.unregisterNativeAdFactory(self, factoryId: "chaputNative")
    chaputNativeAdFactory = nil
    super.applicationWillTerminate(application)
  }
}

class ChaputNativeAdFactory: NSObject, FLTNativeAdFactory {
  func createNativeAd(_ nativeAd: NativeAd, customOptions: [AnyHashable : Any]? = nil) -> NativeAdView {
    let adView = NativeAdView()
    adView.backgroundColor = UIColor.black.withAlphaComponent(0.55)
    adView.layer.cornerRadius = 18
    adView.layer.masksToBounds = true
    adView.layer.borderWidth = 1
    adView.layer.borderColor = UIColor.white.withAlphaComponent(0.22).cgColor

    let headline = UILabel()
    headline.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
    headline.textColor = .white
    headline.numberOfLines = 2

    let body = UILabel()
    body.font = UIFont.systemFont(ofSize: 13, weight: .regular)
    body.textColor = UIColor.white.withAlphaComponent(0.85)
    body.numberOfLines = 2

    let mediaView = MediaView()
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

    let stack = UIStackView(arrangedSubviews: [headline, body])
    stack.axis = .vertical
    stack.spacing = 6

    let bottom = UIStackView(arrangedSubviews: [icon, cta])
    bottom.axis = .horizontal
    bottom.spacing = 10
    bottom.alignment = .center

    let container = UIStackView(arrangedSubviews: [stack, mediaView, bottom])
    container.axis = .vertical
    container.spacing = 10
    container.translatesAutoresizingMaskIntoConstraints = false

    adView.addSubview(container)
    NSLayoutConstraint.activate([
      container.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 14),
      container.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -14),
      container.topAnchor.constraint(equalTo: adView.topAnchor, constant: 14),
      container.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -14),
      mediaView.heightAnchor.constraint(equalToConstant: 140),
      icon.widthAnchor.constraint(equalToConstant: 36),
      icon.heightAnchor.constraint(equalToConstant: 36),
      cta.heightAnchor.constraint(equalToConstant: 36),
    ])

    adView.headlineView = headline
    adView.bodyView = body
    adView.iconView = icon
    adView.callToActionView = cta
    adView.mediaView = mediaView

    headline.text = nativeAd.headline
    if let bodyText = nativeAd.body {
      body.text = bodyText
      body.isHidden = false
    } else {
      body.isHidden = true
    }

    if let iconImage = nativeAd.icon?.image {
      icon.image = iconImage
      icon.isHidden = false
    } else {
      icon.isHidden = true
    }

    if let ctaText = nativeAd.callToAction {
      cta.setTitle(ctaText, for: .normal)
      cta.isHidden = false
    } else {
      cta.isHidden = true
    }

    mediaView.mediaContent = nativeAd.mediaContent
    mediaView.isHidden = false

    adView.nativeAd = nativeAd
    return adView
  }
}
