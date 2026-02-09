package com.example.chaput

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : FlutterActivity() {
    private var chaputNativeAdFactory: ChaputNativeAdFactory? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        chaputNativeAdFactory = ChaputNativeAdFactory(this)
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine,
            "chaputNative",
            chaputNativeAdFactory!!
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        chaputNativeAdFactory?.let {
            GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "chaputNative")
            chaputNativeAdFactory = null
        }
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
