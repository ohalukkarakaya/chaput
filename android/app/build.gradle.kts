import groovy.json.JsonSlurper
import java.io.FileInputStream
import java.util.Base64
import java.util.Properties

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

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.goktigin.chaput"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

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

    dependencies {
        coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    }
}

flutter {
    source = "../.."
}
