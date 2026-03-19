plugins {
    id("com.android.application")
    id("kotlin-android")
    // Add Google Services plugin for Firebase
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.loan_monitoring_flutter" // Your package name
    compileSdk = 35  // CHANGE THIS from flutter.compileSdkVersion to 35

    ndkVersion = "27.0.12077973" // CHANGE THIS from flutter.ndkVersion to the required version

    compileOptions {
        // Flag to enable support for the new language APIs
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.loan_monitoring_flutter" // Your package name
        minSdk = 23  // Keep this as 23 (you already changed it)
        targetSdk = 35 // CHANGE THIS from flutter.targetSdkVersion to 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true // You already have this
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// Add this at the bottom for Firebase
apply(plugin = "com.google.gms.google-services")

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}