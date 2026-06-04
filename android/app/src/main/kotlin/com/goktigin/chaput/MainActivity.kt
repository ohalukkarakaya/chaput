package com.goktigin.chaput

import android.app.NotificationManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : FlutterActivity() {
    private val notificationsChannel = "chaput/notifications"
    private var chaputNativeAdFactory: ChaputNativeAdFactory? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notificationsChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "resetBadge" -> {
                        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        manager.cancelAll()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
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
