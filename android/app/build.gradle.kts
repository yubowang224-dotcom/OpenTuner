plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Secrets are supplied only to the signing process from an external private vault.
// With no signing environment, developer/CI Release builds remain explicitly unsigned.
val releaseStore = System.getenv("OPENTUNER_STORE_FILE")
val releaseStorePassword = System.getenv("OPENTUNER_STORE_PASSWORD")
val releaseAlias = System.getenv("OPENTUNER_KEY_ALIAS")
val releaseKeyPassword = System.getenv("OPENTUNER_KEY_PASSWORD")
val signingValues = listOf(releaseStore, releaseStorePassword, releaseAlias, releaseKeyPassword)
val externalSigning = signingValues.any { !it.isNullOrBlank() }
require(!externalSigning || signingValues.all { !it.isNullOrBlank() }) {
    "Incomplete external release signing environment. No debug-signing fallback."
}
if (externalSigning) {
    val keyFile = file(releaseStore!!).canonicalFile
    require(keyFile.isFile && !keyFile.toPath().startsWith(rootProject.projectDir.parentFile.canonicalFile.toPath())) {
        "The release keystore must exist outside the source project."
    }
}

android {
    namespace = "org.opentune.tuner"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "org.opentune.tuner"
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
        // AGP9 forbids ndk.abiFilters together with ABI splits. Flutter supplies
        // the same three supported ABIs for --split-per-abi.
        if (project.findProperty("split-per-abi") != "true") {
            ndk { abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64") }
        }
        externalNativeBuild {
            cmake { arguments += listOf("-DANDROID_STL=c++_shared", "-DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON") }
        }
    }

    externalNativeBuild {
        cmake { path = file("../../native/android/CMakeLists.txt"); version = "3.22.1" }
    }

    if (externalSigning) {
        signingConfigs {
            create("externalRelease") {
                storeFile = file(releaseStore!!)
                storePassword = releaseStorePassword
                keyAlias = releaseAlias
                keyPassword = releaseKeyPassword
                storeType = "PKCS12"
            }
        }
    }
    buildTypes {
        release {
            signingConfig = if (externalSigning) signingConfigs.getByName("externalRelease") else null
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
