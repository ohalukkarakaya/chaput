import groovy.json.JsonSlurper
import java.io.FileInputStream
import java.util.Base64
import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

fun encodeDartDefine(key: String, value: String): String =
    Base64.getEncoder().encodeToString("$key=$value".toByteArray(Charsets.UTF_8))

val revenueCatAndroidDartDefines = run {
    val keysFile = rootProject.file("../revenuecat.keys.json")
    if (!keysFile.exists()) {
        ""
    } else {
        val keys = JsonSlurper().parse(keysFile) as Map<*, *>
        listOf(
            "REVENUECAT_API_KEY",
            "REVENUECAT_ANDROID_API_KEY",
            "REVENUECAT_ENTITLEMENT_ID",
        ).mapNotNull { key ->
            val value = keys[key]?.toString()?.trim()
            if (value.isNullOrEmpty()) null else encodeDartDefine(key, value)
        }.joinToString(",")
    }
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}

fun chaputConfigValue(
    propertyName: String,
    environmentName: String,
    fallback: String = "",
): String {
    return listOfNotNull(
        providers.gradleProperty(propertyName).orNull,
        localProperties.getProperty(propertyName),
        System.getenv(environmentName),
        fallback,
    ).firstOrNull { it.trim().isNotEmpty() }?.trim().orEmpty()
}

fun androidStringResourceValue(value: String): String {
    return value
}

val metaAppId = chaputConfigValue(
    "chaput.metaAppId",
    "CHAPUT_META_APP_ID",
    "886339164066110",
)
val metaClientToken = chaputConfigValue(
    "chaput.metaClientToken",
    "CHAPUT_META_CLIENT_TOKEN",
    "3185a6e15855a00d9b5fa71e5659333f",
)
val tiktokBusinessAppId = chaputConfigValue(
    "chaput.tiktokBusinessAppId",
    "CHAPUT_TIKTOK_BUSINESS_APP_ID",
    "6777180189",
)
val tiktokAppId = chaputConfigValue(
    "chaput.tiktokAppId",
    "CHAPUT_TIKTOK_APP_ID",
    "7663786815312216084",
)
val tiktokAppEventsAccessToken = chaputConfigValue(
    "chaput.tiktokAppEventsAccessToken",
    "CHAPUT_TIKTOK_APP_EVENTS_ACCESS_TOKEN",
    chaputConfigValue("chaput.tiktokAppSecret", "CHAPUT_TIKTOK_APP_SECRET"),
)

if (revenueCatAndroidDartDefines.isNotBlank()) {
    val existingDartDefines = providers.gradleProperty("dart-defines").orNull
    extensions.extraProperties.set(
        "dart-defines",
        listOf(existingDartDefines, revenueCatAndroidDartDefines)
            .filterNotNull()
            .filter { it.isNotBlank() }
            .joinToString(","),
    )
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val hasReleaseKeystore = listOf(
    "keyAlias",
    "keyPassword",
    "storeFile",
    "storePassword",
).all { key ->
    (keystoreProperties[key] as String?)?.isNotBlank() == true
}

android {
    namespace = "com.goktigin.chaput"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.goktigin.chaput"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        resValue("string", "facebook_app_id", androidStringResourceValue(metaAppId))
        resValue(
            "string",
            "facebook_client_token",
            androidStringResourceValue(metaClientToken),
        )
        resValue(
            "string",
            "chaput_tiktok_business_app_id",
            androidStringResourceValue(tiktokBusinessAppId),
        )
        resValue(
            "string",
            "chaput_tiktok_app_id",
            androidStringResourceValue(tiktokAppId),
        )
        resValue(
            "string",
            "chaput_tiktok_app_events_access_token",
            androidStringResourceValue(tiktokAppEventsAccessToken),
        )

        // flutter_angle currently ships ANGLE native libraries only for arm64.
        // Do not let Play generate installs for ABIs that will crash at 3D init.
        ndk {
            abiFilters += "arm64-v8a"
        }
    }

    packaging {
        jniLibs {
            excludes += setOf(
                "lib/armeabi-v7a/**",
                "lib/x86_64/**",
            )
        }
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.facebook.android:facebook-core:18.3.0")
    implementation("com.github.tiktok:tiktok-business-android-sdk:1.7.0")
}
