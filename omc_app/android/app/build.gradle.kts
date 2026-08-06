import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val isReleaseBuild = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val requiredSigningKeys = listOf(
    "keyAlias",
    "keyPassword",
    "storeFile",
    "storePassword",
)

if (isReleaseBuild) {
    if (!keystorePropertiesFile.exists()) {
        throw GradleException(
            "Missing android/key.properties. Copy key.properties.example, configure the release keystore, then build again."
        )
    }

    val missingSigningKeys = requiredSigningKeys.filter {
        keystoreProperties.getProperty(it)?.trim().isNullOrEmpty()
    }
    if (missingSigningKeys.isNotEmpty()) {
        throw GradleException(
            "android/key.properties is incomplete. Missing: ${missingSigningKeys.joinToString(", ")}"
        )
    }

    val releaseStoreFile = rootProject.file(
        keystoreProperties.getProperty("storeFile")
    )
    if (!releaseStoreFile.isFile) {
        throw GradleException(
            "Release keystore file does not exist: ${releaseStoreFile.absolutePath}"
        )
    }
}

android {
    namespace = "com.wajid.omc_house"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.wajid.omc_house"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = rootProject.file(
                    keystoreProperties.getProperty("storeFile")
                )
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
