package com.goktigin.chaput

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.google.android.gms.ads.nativead.AdChoicesView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory

class ChaputNativeAdFactory(private val context: Context) : NativeAdFactory {
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val adView = LayoutInflater.from(context)
            .inflate(R.layout.native_ad_chaput, null) as NativeAdView

        val headline = adView.findViewById<TextView>(R.id.ad_headline)
        val advertiser = adView.findViewById<TextView>(R.id.ad_advertiser)
        val metaRow = adView.findViewById<LinearLayout>(R.id.ad_meta_row)
        val store = adView.findViewById<TextView>(R.id.ad_store)
        val price = adView.findViewById<TextView>(R.id.ad_price)
        val rating = adView.findViewById<TextView>(R.id.ad_rating)
        val body = adView.findViewById<TextView>(R.id.ad_body)
        val icon = adView.findViewById<ImageView>(R.id.ad_app_icon)
        val cta = adView.findViewById<Button>(R.id.ad_call_to_action)
        val media = adView.findViewById<MediaView>(R.id.ad_media)
        val adChoices = adView.findViewById<AdChoicesView>(R.id.ad_choices)

        adView.headlineView = headline
        adView.advertiserView = advertiser
        adView.storeView = store
        adView.priceView = price
        adView.starRatingView = rating
        adView.bodyView = body
        adView.iconView = icon
        adView.callToActionView = cta
        adView.mediaView = media
        adView.adChoicesView = adChoices

        headline.text = nativeAd.headline
        if (nativeAd.advertiser == null) {
            advertiser.visibility = View.GONE
        } else {
            advertiser.visibility = View.VISIBLE
            advertiser.text = nativeAd.advertiser
        }
        if (nativeAd.body == null) {
            body.visibility = View.GONE
        } else {
            body.visibility = View.VISIBLE
            body.text = nativeAd.body
        }

        if (nativeAd.store == null) {
            store.visibility = View.GONE
        } else {
            store.visibility = View.VISIBLE
            store.text = nativeAd.store
        }

        if (nativeAd.price == null) {
            price.visibility = View.GONE
        } else {
            price.visibility = View.VISIBLE
            price.text = nativeAd.price
        }

        if (nativeAd.starRating == null) {
            rating.visibility = View.GONE
        } else {
            rating.visibility = View.VISIBLE
            rating.text = "${nativeAd.starRating}★"
        }

        metaRow.visibility =
            if (store.visibility == View.VISIBLE || price.visibility == View.VISIBLE || rating.visibility == View.VISIBLE)
                View.VISIBLE
            else
                View.GONE

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
