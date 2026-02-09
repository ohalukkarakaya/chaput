package com.example.chaput

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.NativeAdFactory

class ChaputNativeAdFactory(private val context: Context) : NativeAdFactory {
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val adView = LayoutInflater.from(context)
            .inflate(R.layout.native_ad_chaput, null) as NativeAdView

        val headline = adView.findViewById<TextView>(R.id.ad_headline)
        val body = adView.findViewById<TextView>(R.id.ad_body)
        val icon = adView.findViewById<ImageView>(R.id.ad_app_icon)
        val cta = adView.findViewById<Button>(R.id.ad_call_to_action)
        val media = adView.findViewById<MediaView>(R.id.ad_media)

        adView.headlineView = headline
        adView.bodyView = body
        adView.iconView = icon
        adView.callToActionView = cta
        adView.mediaView = media

        headline.text = nativeAd.headline
        if (nativeAd.body == null) {
            body.visibility = View.GONE
        } else {
            body.visibility = View.VISIBLE
            body.text = nativeAd.body
        }

        if (nativeAd.icon == null) {
            icon.visibility = View.GONE
        } else {
            icon.setImageDrawable(nativeAd.icon!!.drawable)
            icon.visibility = View.VISIBLE
        }

        if (nativeAd.callToAction == null) {
            cta.visibility = View.GONE
        } else {
            cta.text = nativeAd.callToAction
            cta.visibility = View.VISIBLE
        }

        if (nativeAd.mediaContent != null) {
            media.setMediaContent(nativeAd.mediaContent)
            media.visibility = View.VISIBLE
        } else {
            media.visibility = View.GONE
        }

        adView.setNativeAd(nativeAd)
        return adView
    }
}
