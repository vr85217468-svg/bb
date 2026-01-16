plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.test7"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "25.2.9519653"  // نسخة مستقرة ومتوافقة مع Agora

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.test7"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true
    }

    // ✅ تقسيم APK حسب معمارية المعالج لتقليل الحجم
    splits {
        abi {
            isEnable = true
            reset()
            // تضمين المعماريات الأكثر استخداماً فقط
            include("arm64-v8a", "armeabi-v7a")
            // عدم إنشاء APK شامل (universal)
            isUniversalApk = false
        }
    }

    buildTypes {
        release {
            // نستخدم debug signing مؤقتًا لتفادي مشاكل keystore
            signingConfig = signingConfigs.getByName("debug")

            // ✅ تفعيل ProGuard + تقليص الموارد
            isMinifyEnabled = true
            isShrinkResources = true // ✅ تم التفعيل لحذف الموارد غير المستخدمة

            // تطبيق قواعد ProGuard التي تجبر R8 على تجاهل Firebase
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )

            // Release حقيقي
            isDebuggable = false
        }
        
        debug {
            // تطبيق نفس القواعد في Debug لاكتشاف المشاكل مبكرًا
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        resources {
            excludes += setOf(
                "/META-INF/AL2.0",
                "/META-INF/LGPL2.1",
                // ✅ استبعاد ملفات Firebase نهائيًا
                "**/google-services.json",
                "**/firebase-*.json",
                "META-INF/com.google.firebase/**"
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // ✅ تم حذف Firebase نهائيًا - نستخدم Pushy بدلاً منه
    // implementation("com.google.firebase:firebase-messaging:24.0.0") // ❌ محذوف
}

flutter {
    source = "../.."
}
