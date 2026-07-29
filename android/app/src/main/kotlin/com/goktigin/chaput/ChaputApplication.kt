package com.goktigin.chaput

import io.flutter.app.FlutterApplication

class ChaputApplication : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        ChaputAttributionManager.initialize(this)
    }
}
