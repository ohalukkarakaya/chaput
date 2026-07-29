package com.goktigin.chaput

import android.app.Application
import android.content.pm.ApplicationInfo
import android.os.Bundle
import android.util.Log
import com.facebook.FacebookSdk
import com.facebook.LoggingBehavior
import com.facebook.appevents.AppEventsConstants
import com.facebook.appevents.AppEventsLogger
import com.tiktok.TikTokBusinessSdk
import com.tiktok.appevents.base.EventName
import com.tiktok.appevents.contents.TTContentParams
import com.tiktok.appevents.contents.TTContentsEventConstants.Currency as TikTokCurrency
import com.tiktok.appevents.contents.TTPurchaseEvent
import java.math.BigDecimal
import java.util.Collections
import java.util.Locale
import java.util.Currency as JavaCurrency

object ChaputAttributionManager {
    private const val TAG = "ChaputAttribution"

    private val reportedPurchaseEventIds = Collections.synchronizedSet(mutableSetOf<String>())
    private val subscriptionProductIds = setOf(
        "chaput_plus_month",
        "chaput_pro_month",
        "chaput_pro_year",
    )

    @Volatile
    private var initializationAttempted = false

    @Volatile
    private var metaLogger: AppEventsLogger? = null

    @Volatile
    private var tiktokReady = false

    fun initialize(application: Application) {
        if (initializationAttempted) return
        synchronized(this) {
            if (initializationAttempted) return
            initializationAttempted = true
            initializeMeta(application)
            initializeTikTok(application)
        }
    }

    fun trackEvent(name: String, event: Map<*, *>) {
        when (name) {
            "login" -> trackLogin()
            "signup" -> trackSignUp()
            "purchase" -> trackVerifiedPurchase(event)
            else -> Unit
        }
    }

    private fun initializeMeta(application: Application) {
        runCatching {
            FacebookSdk.setAutoInitEnabled(true)
            FacebookSdk.setAutoLogAppEventsEnabled(true)
            FacebookSdk.setAdvertiserIDCollectionEnabled(false)

            if (isDebuggable(application)) {
                FacebookSdk.setIsDebugEnabled(true)
                FacebookSdk.addLoggingBehavior(LoggingBehavior.APP_EVENTS)
            }

            if (!FacebookSdk.isInitialized()) {
                FacebookSdk.sdkInitialize(application)
            }

            metaLogger = AppEventsLogger.newLogger(application)
            Log.d(
                TAG,
                "Meta App Events configured autoLog=${FacebookSdk.getAutoLogAppEventsEnabled()} " +
                    "advertiserId=${FacebookSdk.getAdvertiserIDCollectionEnabled()}",
            )
        }.onFailure { error ->
            Log.w(TAG, "Meta App Events initialization failed: ${error.javaClass.simpleName}")
        }
    }

    private fun initializeTikTok(application: Application) {
        val accessToken = application.getString(
            R.string.chaput_tiktok_app_events_access_token,
        ).trim()
        val businessAppId = application.getString(R.string.chaput_tiktok_business_app_id).trim()
        val tiktokAppId = application.getString(R.string.chaput_tiktok_app_id).trim()

        if (accessToken.isEmpty() || businessAppId.isEmpty() || tiktokAppId.isEmpty()) {
            Log.w(TAG, "TikTok Business SDK not initialized: missing app id or access token")
            return
        }

        runCatching {
            if (TikTokBusinessSdk.isInitialized()) {
                tiktokReady = true
                return@runCatching
            }

            val config = TikTokBusinessSdk.TTConfig(application, accessToken)
                .setAppId(businessAppId)
                .setTTAppId(tiktokAppId)
                .disableAdvertiserIDCollection()
                .disableAutoIapTrack()

            if (isDebuggable(application)) {
                config.openDebugMode().setLogLevel(TikTokBusinessSdk.LogLevel.DEBUG)
                TikTokBusinessSdk.enableDebugMode()
            } else {
                config.setLogLevel(TikTokBusinessSdk.LogLevel.WARN)
                TikTokBusinessSdk.disableDebugMode()
            }

            TikTokBusinessSdk.initializeSdk(
                config,
                object : TikTokBusinessSdk.TTInitCallback {
                    override fun success() {
                        tiktokReady = true
                        Log.d(TAG, "TikTok Business SDK initialized")
                    }

                    override fun fail(code: Int, message: String?) {
                        tiktokReady = false
                        Log.w(TAG, "TikTok Business SDK initialization failed code=$code")
                    }
                },
            )
        }.onFailure { error ->
            tiktokReady = false
            Log.w(TAG, "TikTok Business SDK initialization failed: ${error.javaClass.simpleName}")
        }
    }

    private fun trackLogin() {
        runCatching {
            val params = Bundle().apply {
                putString("login_method", "email")
            }
            metaLogger?.logEvent("user_login", params)
        }.onFailure { error ->
            Log.w(TAG, "Meta login event failed: ${error.javaClass.simpleName}")
        }

        runCatching {
            if (tiktokReady) {
                TikTokBusinessSdk.trackTTEvent(EventName.LOGIN)
            }
        }.onFailure { error ->
            Log.w(TAG, "TikTok login event failed: ${error.javaClass.simpleName}")
        }
    }

    private fun trackSignUp() {
        runCatching {
            metaLogger?.logEvent(AppEventsConstants.EVENT_NAME_COMPLETED_REGISTRATION)
        }.onFailure { error ->
            Log.w(TAG, "Meta signup event failed: ${error.javaClass.simpleName}")
        }

        runCatching {
            if (tiktokReady) {
                TikTokBusinessSdk.trackTTEvent(EventName.REGISTRATION)
            }
        }.onFailure { error ->
            Log.w(TAG, "TikTok signup event failed: ${error.javaClass.simpleName}")
        }
    }

    private fun trackVerifiedPurchase(event: Map<*, *>) {
        val transactionId = trimmedString(event["transactionId"]) ?: return
        val productId = trimmedString(event["productId"]) ?: return

        if (!reportedPurchaseEventIds.add(transactionId)) return

        val currency = trimmedString(event["currency"])?.uppercase(Locale.US)
        val value = doubleValue(event["value"])
        val contentType = contentType(productId)
        val contentCategory = contentCategory(productId)

        trackMetaPurchase(
            transactionId = transactionId,
            productId = productId,
            currency = currency,
            value = value,
            contentType = contentType,
        )
        trackTikTokPurchase(
            transactionId = transactionId,
            productId = productId,
            currency = currency,
            value = value,
            contentType = contentType,
            contentCategory = contentCategory,
        )
    }

    private fun trackMetaPurchase(
        transactionId: String,
        productId: String,
        currency: String?,
        value: Double?,
        contentType: String,
    ) {
        runCatching {
            val params = Bundle().apply {
                putString(AppEventsConstants.EVENT_PARAM_ORDER_ID, transactionId)
                putString(AppEventsConstants.EVENT_PARAM_CONTENT_ID, productId)
                putString(AppEventsConstants.EVENT_PARAM_CONTENT_TYPE, contentType)
            }

            val amount = value?.takeIf { it.isFinite() }
            val javaCurrency = javaCurrency(currency)
            if (amount != null && javaCurrency != null) {
                metaLogger?.logPurchase(BigDecimal.valueOf(amount), javaCurrency, params)
            } else {
                if (currency != null) {
                    params.putString(AppEventsConstants.EVENT_PARAM_CURRENCY, currency)
                }
                if (amount != null) {
                    params.putDouble(AppEventsConstants.EVENT_PARAM_VALUE_TO_SUM, amount)
                }
                metaLogger?.logEvent(AppEventsConstants.EVENT_NAME_PURCHASED, params)
            }
        }.onFailure { error ->
            Log.w(TAG, "Meta purchase event failed: ${error.javaClass.simpleName}")
        }
    }

    private fun trackTikTokPurchase(
        transactionId: String,
        productId: String,
        currency: String?,
        value: Double?,
        contentType: String,
        contentCategory: String,
    ) {
        runCatching {
            if (!tiktokReady) return@runCatching

            val contentBuilder = TTContentParams.newBuilder()
                .setContentId(productId)
                .setContentCategory(contentCategory)
                .setContentName(productId)
                .setBrand("Chaput")
                .setQuantity(1)
            if (value != null && value.isFinite()) {
                contentBuilder.setPrice(value.toFloat())
            }

            val purchaseBuilder = TTPurchaseEvent.newBuilder(transactionId)
                .setDescription(productId)
                .setContentId(productId)
                .setContentType(contentType)
                .setContents(contentBuilder.build())

            val tiktokCurrency = tiktokCurrency(currency)
            if (tiktokCurrency != null) {
                purchaseBuilder.setCurrency(tiktokCurrency)
            }
            if (value != null && value.isFinite()) {
                purchaseBuilder.setValue(value)
            }

            TikTokBusinessSdk.trackTTEvent(purchaseBuilder.build())
        }.onFailure { error ->
            Log.w(TAG, "TikTok purchase event failed: ${error.javaClass.simpleName}")
        }
    }

    private fun trimmedString(value: Any?): String? {
        return (value as? String)?.trim()?.takeIf { it.isNotEmpty() }
    }

    private fun doubleValue(value: Any?): Double? {
        val parsed = when (value) {
            is Double -> value
            is Float -> value.toDouble()
            is Number -> value.toDouble()
            is String -> value.trim().toDoubleOrNull()
            else -> null
        }
        return parsed?.takeIf { it.isFinite() }
    }

    private fun logicalProductId(productId: String): String {
        return productId.substringBefore(":").trim()
    }

    private fun contentType(productId: String): String {
        return if (subscriptionProductIds.contains(logicalProductId(productId))) {
            "subscription"
        } else {
            "consumable"
        }
    }

    private fun contentCategory(productId: String): String {
        val logicalId = logicalProductId(productId)
        return when {
            subscriptionProductIds.contains(logicalId) -> "subscription"
            logicalId.startsWith("chaput_bind_") -> "bind"
            logicalId.startsWith("chaput_hidden_") -> "hidden"
            logicalId.startsWith("chaput_special_") -> "special"
            logicalId.startsWith("chaput_whisper_") -> "whisper"
            logicalId.startsWith("chaput_revive_") -> "revive"
            else -> "consumable"
        }
    }

    private fun javaCurrency(code: String?): JavaCurrency? {
        if (code.isNullOrBlank()) return null
        return runCatching { JavaCurrency.getInstance(code.uppercase(Locale.US)) }.getOrNull()
    }

    private fun tiktokCurrency(code: String?): TikTokCurrency? {
        if (code.isNullOrBlank()) return null
        return runCatching { TikTokCurrency.valueOf(code.uppercase(Locale.US)) }.getOrNull()
    }

    private fun isDebuggable(application: Application): Boolean {
        return (application.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
    }
}
