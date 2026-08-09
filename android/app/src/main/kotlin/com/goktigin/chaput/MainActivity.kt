package com.goktigin.chaput

import android.app.Application
import android.app.NotificationManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import me.leolin.shortcutbadger.ShortcutBadger

class MainActivity : FlutterActivity() {
    private val notificationsChannel = "chaput/notifications"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ChaputAttributionBridge.register(
            flutterEngine.dartExecutor.binaryMessenger,
            application as Application,
        )
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notificationsChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setBadge" -> {
                        val count = call.argument<Int>("count") ?: 0
                        setBadgeCount(count)
                        result.success(null)
                    }
                    "resetBadge" -> {
                        resetBadgeCount()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun setBadgeCount(count: Int) {
        val safeCount = count.coerceAtLeast(0)
        if (safeCount == 0) {
            resetBadgeCount()
            return
        }
        try {
            ShortcutBadger.applyCount(applicationContext, safeCount)
        } catch (_: Throwable) {
            // Launcher badge support is device-specific on Android.
        }
    }

    private fun resetBadgeCount() {
        try {
            ShortcutBadger.removeCount(applicationContext)
        } catch (_: Throwable) {
            // Launcher badge support is device-specific on Android.
        }
        try {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancelAll()
        } catch (_: Throwable) {
            // Notification cleanup should not block badge reset.
        }
    }
}
