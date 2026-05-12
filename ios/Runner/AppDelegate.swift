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

    let body = UILabel()
    body.font = UIFont.systemFont(ofSize: 13, weight: .regular)
    body.textColor = UIColor.white.withAlphaComponent(0.85)
    body.numberOfLines = 1

    let advertiser = UILabel()
    advertiser.font = UIFont.systemFont(ofSize: 12, weight: .medium)
    advertiser.textColor = UIColor.white.withAlphaComponent(0.72)
    advertiser.numberOfLines = 1

    let store = UILabel()
    store.font = UIFont.systemFont(ofSize: 12, weight: .medium)
    store.textColor = UIColor.white.withAlphaComponent(0.72)
    store.numberOfLines = 1

    let price = UILabel()
    price.font = UIFont.systemFont(ofSize: 12, weight: .medium)
    price.textColor = UIColor.white.withAlphaComponent(0.72)
    price.numberOfLines = 1

    let rating = UILabel()
    rating.font = UIFont.systemFont(ofSize: 12, weight: .medium)
    rating.textColor = UIColor.white.withAlphaComponent(0.72)
    rating.numberOfLines = 1

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
    sponsored.translatesAutoresizingMaskIntoConstraints = false
    mediaContainer.addSubview(mediaView)
    mediaContainer.addSubview(sponsored)
    mediaContainer.addSubview(adChoices)

    let metaRow = UIStackView(arrangedSubviews: [advertiser, store, price, rating])
    metaRow.spacing = 8
    metaRow.alignment = .center
    metaRow.distribution = .fillProportionally

    let details = UIStackView(arrangedSubviews: [headline, metaRow, body])
    details.axis = .vertical
    details.spacing = 4

    let bottom = UIStackView(arrangedSubviews: [icon, cta])
    bottom.axis = .horizontal
    bottom.spacing = 10
    bottom.alignment = .center

    let container = UIStackView(arrangedSubviews: [mediaContainer, details, bottom])
    container.axis = .vertical
    container.spacing = 10
    container.translatesAutoresizingMaskIntoConstraints = false

    adView.addSubview(container)

    let mediaMinHeight = mediaContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 180)
    let mediaMaxHeight = mediaContainer.heightAnchor.constraint(lessThanOrEqualToConstant: 240)
    var mediaAspect: NSLayoutConstraint?
    let aspectRatio = CGFloat(nativeAd.mediaContent.aspectRatio)
    if aspectRatio > 0 {
      mediaAspect = mediaContainer.heightAnchor.constraint(equalTo: mediaContainer.widthAnchor, multiplier: 1 / aspectRatio)
      mediaAspect?.priority = UILayoutPriority(999)
    } else {
      mediaAspect = mediaContainer.heightAnchor.constraint(equalToConstant: 220)
      mediaAspect?.priority = .required
    }

    NSLayoutConstraint.activate([
      container.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 14),
      container.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -14),
      container.topAnchor.constraint(equalTo: adView.topAnchor, constant: 14),
      container.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -14),
      mediaView.leadingAnchor.constraint(equalTo: mediaContainer.leadingAnchor),
      mediaView.trailingAnchor.constraint(equalTo: mediaContainer.trailingAnchor),
      mediaView.topAnchor.constraint(equalTo: mediaContainer.topAnchor),
      mediaView.bottomAnchor.constraint(equalTo: mediaContainer.bottomAnchor),
      sponsored.leadingAnchor.constraint(equalTo: mediaContainer.leadingAnchor, constant: 12),
      sponsored.topAnchor.constraint(equalTo: mediaContainer.topAnchor, constant: 12),
      sponsored.trailingAnchor.constraint(lessThanOrEqualTo: adChoices.leadingAnchor, constant: -10),
      adChoices.trailingAnchor.constraint(equalTo: mediaContainer.trailingAnchor, constant: -8),
      adChoices.topAnchor.constraint(equalTo: mediaContainer.topAnchor, constant: 8),
      adChoices.widthAnchor.constraint(greaterThanOrEqualToConstant: 24),
      adChoices.heightAnchor.constraint(greaterThanOrEqualToConstant: 24),
      icon.widthAnchor.constraint(equalToConstant: 36),
      icon.heightAnchor.constraint(equalToConstant: 36),
      cta.heightAnchor.constraint(equalToConstant: 36),
      mediaMinHeight,
      mediaMaxHeight,
    ])
    if let mediaAspect {
      mediaAspect.isActive = true
    }

    adView.headlineView = headline
    adView.advertiserView = advertiser
    adView.storeView = store
    adView.priceView = price
    adView.starRatingView = rating
    adView.bodyView = body
    adView.iconView = icon
    adView.callToActionView = cta
    adView.mediaView = mediaView
    adView.adChoicesView = adChoices

    headline.text = nativeAd.headline
    if let advertiserText = nativeAd.advertiser {
      advertiser.text = advertiserText
      advertiser.isHidden = false
    } else {
      advertiser.isHidden = true
    }
    if let bodyText = nativeAd.body {
      body.text = bodyText
      body.isHidden = false
    } else {
      body.isHidden = true
    }

    if let storeText = nativeAd.store {
      store.text = storeText
      store.isHidden = false
    } else {
      store.isHidden = true
    }

    if let priceText = nativeAd.price {
      price.text = priceText
      price.isHidden = false
    } else {
      price.isHidden = true
    }

    if let starRating = nativeAd.starRating {
      rating.text = "\(starRating)★"
      rating.isHidden = false
    } else {
      rating.isHidden = true
    }

    metaRow.isHidden = advertiser.isHidden && store.isHidden && price.isHidden && rating.isHidden

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
