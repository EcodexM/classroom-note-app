plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    id("com.google.firebase.firebase-perf")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.notex"
    compileSdk = 33

    defaultConfig {
        applicationId = "com.example.notex"
        minSdk = 21
        targetSdk = 33
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.6.10")
    implementation("com.google.firebase:firebase-analytics-ktx:20.0.2")
    implementation("com.google.firebase:firebase-auth-ktx:21.0.1")
    implementation("com.google.firebase:firebase-firestore-ktx:24.0.0")
    implementation("com.google.firebase:firebase-storage-ktx:20.0.0")
}

apply(plugin = "com.google.gms.google-services")
apply(plugin = "com.google.firebase.crashlytics")
apply(plugin = "com.google.firebase.firebase-perf")

flutter {
    source = "../.."
}
