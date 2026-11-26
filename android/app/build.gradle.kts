import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.isFile) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

// Debug tetap bisa dijalankan tanpa key pribadi; release wajib memakai key sendiri.
if (gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }) {
    check(keystorePropertiesFile.isFile) {
        "Signing release belum siap. Isi android/key.properties mengikuti android/key.properties.example dengan keystore release yang sama."
    }
    for (name in listOf("storeFile", "storePassword", "keyAlias", "keyPassword")) {
        check(!keystoreProperties.getProperty(name).isNullOrBlank()) {
            "Properti signing '$name' belum diisi di android/key.properties."
        }
    }
    check(rootProject.file(keystoreProperties.getProperty("storeFile")).isFile) {
        "File keystore release tidak ditemukan. Pulihkan key yang sama dari backup."
    }
}

android {
    namespace = "id.waroengku.kasir"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "id.waroengku.kasir"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { rootProject.file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            isDebuggable = false
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
