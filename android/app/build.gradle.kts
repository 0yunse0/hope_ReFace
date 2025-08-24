plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // 이 값을 36으로 유지합니다.
    compileSdk = 36

    // 이 줄을 유지합니다.
    ndkVersion = "27.0.12077973"

    namespace = "com.example.face_newversion"

    // compileSdk = flutter.compileSdkVersion // ## 이 줄을 삭제했습니다. ##
    // ndkVersion = flutter.ndkVersion     // ## 이 줄을 삭제했습니다. ##

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.face_newversion"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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