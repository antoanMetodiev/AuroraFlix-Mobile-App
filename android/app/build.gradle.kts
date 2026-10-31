import java.util.Properties

// Release signing key (android/key.properties + upload-keystore.jks, both
// kept out of git). Every APK we publish must be signed with the same key,
// or phones refuse to install it as an update.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "cloud.auroraflix.auroraflix"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // ota_update (in-app APK updates) needs java.time & co. on old Androids.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "cloud.auroraflix.auroraflix"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // We publish one APK per ABI (Cloudflare serves files up to 25 MiB):
    // arm64 for phones, and with `--target-platform android-arm` 32-bit ARM
    // for Android TVs (most run a 32-bit system on a 64-bit chip). Plugins
    // ship native libs for every ABI, and ndk.abiFilters didn't drop them —
    // any other ABI's folder in the APK must go, or a device that supports it
    // picks it and finds no libflutter.so there.
    val abi = if (project.findProperty("target-platform") == "android-arm") "armeabi-v7a" else "arm64-v8a"
    packaging {
        jniLibs {
            excludes += listOf("arm64-v8a", "armeabi-v7a", "x86", "x86_64").filter { it != abi }.map { "lib/$it/**" }
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (keystoreProperties.isEmpty) signingConfigs.getByName("debug") else signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
