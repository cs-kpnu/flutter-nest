plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.template_8"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Вмикаємо підтримку нових функцій Java (це вимагають бібліотеки)
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.template_8"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Вимикаємо стиснення, щоб уникнути зайвих помилок
            isMinifyEnabled = false
            isShrinkResources = false

            // 🔥 Критичний фікс для Windows (щоб збірка не падала)
            ndk {
                debugSymbolLevel = "SYMBOL_TABLE"
            }
        }
    }
}

dependencies {
    // 🔥 ВИПРАВЛЕНИЙ СИНТАКСИС: Використовуємо add()
    add("coreLibraryDesugaring", "com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}