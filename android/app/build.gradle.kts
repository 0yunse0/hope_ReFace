plugins {
    id("com.android.application")
    id("kotlin-android")
<<<<<<< HEAD
    
=======
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
>>>>>>> origin/main
    id("dev.flutter.flutter-gradle-plugin")

    id("com.google.gms.google-services")
}

<<<<<<< HEAD
dependencies {
  implementation(platform("com.google.firebase:firebase-bom:34.0.0"))
} 

android {
    namespace = "com.example.reface"
=======
android {
    namespace = "com.example.test_auth_app"
>>>>>>> origin/main
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
<<<<<<< HEAD
        applicationId = "com.example.reface"
=======
        applicationId = "com.example.test_auth_app"
>>>>>>> origin/main
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
<<<<<<< HEAD
=======

dependencies {
  implementation(platform("com.google.firebase:firebase-bom:34.0.0"))
} 
>>>>>>> origin/main
