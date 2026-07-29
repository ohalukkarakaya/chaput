package com.goktigin.chaput

import android.app.Application
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

object ChaputAttributionBridge {
    private const val CHANNEL_NAME = "chaput/attribution"

    fun register(messenger: BinaryMessenger, application: Application) {
        MethodChannel(messenger, CHANNEL_NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "trackingAuthorizationStatus" -> result.success(-1)
                "requestTrackingAuthorization" -> result.success(-1)
                "appleSearchAdsToken" -> result.success(null)
                "trackEvent" -> {
                    val event = call.arguments as? Map<*, *>
                    val name = event?.get("name") as? String
                    if (name.isNullOrBlank()) {
                        result.error("invalid_event", "Missing event name", null)
                        return@setMethodCallHandler
                    }

                    ChaputAttributionManager.initialize(application)
                    ChaputAttributionManager.trackEvent(name, event)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
